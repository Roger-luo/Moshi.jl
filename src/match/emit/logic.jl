function decons(::Type{Pattern.And}, ctx::PatternContext, pat::Pattern.Type)
    return function and(value)
        return Expr(:&&, decons(ctx, pat.:1)(value), decons(ctx, pat.:2)(value))
    end
end

function or_binding_message(lhs::Dict{Symbol,Int}, rhs::Dict{Symbol,Int})::String
    names = sort!([
        name for
        name in union(keys(lhs), keys(rhs)) if get(lhs, name, 0) != get(rhs, name, 0)
    ])
    function detail(name)
        left, right = get(lhs, name, 0), get(rhs, name, 0)
        iszero(right) && return "`$name` is bound only on the left"
        iszero(left) && return "`$name` is bound only on the right"
        return "`$name` is bound $left times on the left and $right times on the right"
    end
    return "both sides of `||` must bind the same variables: $(join(map(detail, names), "; "))"
end

function decons(::Type{Pattern.Or}, ctx::PatternContext, pat::Pattern.Type)
    return function or(value)
        variable_count = copy(ctx.variable_count)
        lhs = decons(ctx, pat.:1)(value)
        lhs_count = copy(ctx.variable_count)
        copy!(ctx.variable_count, variable_count)
        rhs = decons(ctx, pat.:2)(value)
        # the arm binds every name either side binds, so the matching side must bind it
        lhs_count == ctx.variable_count ||
            throw(PatternSyntaxError(or_binding_message(lhs_count, ctx.variable_count)))
        return quote
            $lhs || $rhs
        end
    end
end
