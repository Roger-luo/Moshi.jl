function emit(info::EmitInfo)
    isempty(info.cases) && return :($Base.throw($Match.SyntaxError("empty match body")))

    matches = expr_map(info.cases, info.exprs, info.lines) do case, expr, line
        pinfo = PatternContext(info, case)
        if isa_variant(case, Pattern.Err)
            return Expr(:block, line, :($Base.throw($Match.SyntaxError($(case.:1)))))
        end

        cond = decons(pinfo, case)(info.value_holder)
            Expr(
                :if,
                :($cond && $(emit_check_duplicated_variables(pinfo))),
                Expr(
                    :block,
                    line,
                    quote
                        $(info.return_var) = let $(emit_bind_match_values(pinfo)...)
                            $expr
                        end
                        @goto $(info.final_label)
                    end,
                ),
            )
    end

    return Expr(
        :block,
        :($(info.value_holder) = $(info.value)),
        matches,
        last(info.lines),
        :($Base.error("matching non-exhaustic")),
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
