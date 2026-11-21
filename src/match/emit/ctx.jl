struct PatternContext
    info::EmitInfo
    scope_prefix::Symbol
    variable_count::Dict{Symbol,Int}
    scope::Dict{Symbol,Set{Symbol}}
end

function PatternContext(info::EmitInfo, case::Pattern.Type)
    return PatternContext(
        info, gensym(variant_name(case)), Dict{Symbol,Int}(), Dict{Symbol,Set{Symbol}}()
    )
end

function placeholder(ctx::PatternContext, name::Symbol, count::Int)
    return Symbol("##", ctx.scope_prefix, "#", name, "#", count)
end

function var!(ctx::PatternContext, name::Symbol)
    count = get(ctx.variable_count, name, 0) + 1
    ctx.variable_count[name] = count
    return placeholder(ctx, name, count)
end

function Base.setindex!(ctx::PatternContext, v::Symbol, k::Symbol)
    push!(get!(Set{Symbol}, ctx.scope, k), v)
    return ctx
end

function emit_check_duplicated_variables(ctx::PatternContext)
    stmts = []
    for (var, values) in ctx.scope
        length(values) > 1 || continue
        first_value, rest = Iterators.peel(values)
        for each in rest
            push!(stmts, equal_expr(first_value, each))
        end
    end
    return foldl(and_expr, stmts; init=true)
end

"""
Code testing `lhs == rhs` as a match condition. A `missing` result does not match, so `==`
is compared to `true` rather than used as the condition directly.
"""
equal_expr(lhs, rhs) = xcall(Base, :(===), xcall(Base, :(==), lhs, rhs), true)

function emit_bind_match_values(ctx::PatternContext)
    return map(collect(keys(ctx.scope))) do k
        return :($k = $(first(ctx.scope[k])))
    end
end

function and_expr(lhs, rhs)
    if lhs == true
        return rhs
    elseif rhs == true
        return lhs
    else
        return Expr(:&&, lhs, rhs)
    end
end

and_expr(lhs, rhs, more...) = and_expr(and_expr(lhs, rhs), more...)
