function decons(::Type{Pattern.Expression}, ctx::PatternContext, pat::Pattern.Type)
    return function expression(value)
        return and_expr(
            :($value isa Expr),
            :($value.head == $(QuoteNode(pat.head))),
            map(enumerate(pat.args)) do (idx, each)
                entry = :($value.args[$idx])
                decons(ctx, each)(entry)
            end...
        )
    end
end
