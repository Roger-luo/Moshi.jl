function emit(info::EmitInfo)
    isempty(info.cases) && return x_syntax_error("empty match body", info.source)

    matches = expr_map(info.cases, info.exprs, info.lines) do case, expr, line
        ctx = PatternContext(info, case)
        if isa_variant(case, Pattern.Err)
            return x_syntax_error(case.:1, line)
        end

        cond = decons(ctx, case)(info.value_holder)
        maybe_if(
            and_expr(cond, emit_check_duplicated_variables(ctx)),
            Expr(
                :block,
                line,
                Expr(
                    :(=),
                    info.return_var,
                    Expr(:let, Expr(:block, emit_bind_match_values(ctx)...), expr),
                ),
                :(@goto $(info.final_label)),
            ),
        )
    end

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

function maybe_if(cond, body)
    if cond == true
        return body
    end
    return Expr(:if, cond, body)
end
