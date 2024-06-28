function decons(::Type{Pattern.And}, ctx::PatternContext, pat::Pattern.Type)
    return function and(value)
        return quote
            $(decons(ctx, pat.:1)(value)) && $(decons(ctx, pat.:2)(value))
        end
    end
end

function decons(::Type{Pattern.Or}, ctx::PatternContext, pat::Pattern.Type)
    return function or(value)
        variable_count = copy(ctx.variable_count)
        lhs = decons(ctx, pat.:1)(value)
        copy!(ctx.variable_count, variable_count)
        rhs = decons(ctx, pat.:2)(value)
        return quote
            $lhs || $rhs
        end
    end
end
