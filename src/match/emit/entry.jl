function emit(info::EmitInfo)
    isempty(info.cases) && return x_syntax_error("empty match body", info.source)

    matches = expr_map(info.cases, info.exprs, info.lines) do case, expr, line
        ctx = PatternContext(info, case)
        if isa_variant(case, Pattern.Err)
            return x_syntax_error(case.:1, line)
        end

        cond = try
            decons(ctx, case)(info.value_holder)
        catch err
            err isa PatternSyntaxError || rethrow()
            throw(PatternSyntaxError(err.msg, something(line, info.source)))
        end
        return maybe_if(
            and_expr(cond, emit_check_duplicated_variables(ctx)),
            Expr(
                :block,
                line,
                Expr(
                    :(=),
                    info.return_var,
                    Expr(:let, Expr(:block, emit_bind_match_values(ctx)...), expr),
                ),
                Expr(:symbolicgoto, info.final_label),
            ),
        )
    end
    verify(info)

    return Expr(
        :block,
        :($(info.value_holder) = $(info.value)),
        matches,
        last(info.lines),
        :($Base.error("matching non-exhaustive")),
        :($Base.@label $(info.final_label)),
        info.return_var,
    )
end

function decons(ctx::PatternContext, pat::Pattern.Type)
    return decons(variant_type(pat), ctx, pat)
end

function decons(::Type, ctx::PatternContext, pat::Pattern.Type)
    return error("invalid pattern: $pat")
end

# an invalid sub-pattern; a whole invalid arm is emitted as a run-time error instead
function decons(::Type{Pattern.Err}, ::PatternContext, pat::Pattern.Type)
    return throw(PatternSyntaxError(pat.:1))
end

"""
`body` when `cond` holds. `cond` runs as jumps rather than as a `Bool` value, so a pattern
variable assigned on every path to `body` is defined there; an `||` in a `Bool` value
leaves Julia a path where it is undefined.
"""
function maybe_if(cond, body)
    cond == true && return body
    matched, unmatched = gensym(:matched), gensym(:unmatched)
    return Expr(
        :block,
        emit_branch(cond, matched, unmatched)...,
        Expr(:symboliclabel, matched),
        body,
        Expr(:symboliclabel, unmatched),
    )
end

"Statements that run `cond`, then jump to label `on_true` or `on_false`."
function emit_branch(cond, on_true::Symbol, on_false::Symbol)::Vector{Any}
    cond === true && return Any[Expr(:symbolicgoto, on_true)]
    cond === false && return Any[Expr(:symbolicgoto, on_false)]
    if Meta.isexpr(cond, (:&&, :||))
        stmts = []
        for arg in cond.args[1:(end - 1)]
            next = gensym(:next)
            targets = cond.head === :&& ? (next, on_false) : (on_true, next)
            append!(stmts, emit_branch(arg, targets...))
            push!(stmts, Expr(:symboliclabel, next))
        end
        return append!(stmts, emit_branch(last(cond.args), on_true, on_false))
    end
    idx = if Meta.isexpr(cond, :block)
        findlast(arg -> !(arg isa LineNumberNode), cond.args)
    else
        nothing
    end
    if !isnothing(idx)
        return Any[
            cond.args[1:(idx - 1)]...;
            emit_branch(cond.args[idx], on_true, on_false)
        ]
    end
    return Any[Expr(:if, cond, Expr(:symbolicgoto, on_true), Expr(:symbolicgoto, on_false))]
end
