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

function var!(ctx::PatternContext, name::Symbol)
    count = get(ctx.variable_count, name, 0) + 1
    ctx.variable_count[name] = count
    return Symbol("##", ctx.scope_prefix, "#", name, "#", count)
end

function Base.setindex!(ctx::PatternContext, v::Symbol, k::Symbol)
    push!(get!(Set{Symbol}, ctx.scope, k), v)
    return ctx
end

function emit_check_duplicated_variables(ctx::PatternContext)
    stmts = []
    for (var, values) in ctx.scope
        length(values) > 1 || continue
        compare_expr = []
        for (i, each) in enumerate(values)
            push!(compare_expr, each)

            if i < length(values)
                push!(compare_expr, :(==))
            end
        end
        push!(stmts, Expr(:comparison, compare_expr...))
    end
    return foldl(and_expr, stmts; init=true)
end

function emit_bind_match_values(ctx::PatternContext)
    return map(collect(keys(ctx.scope))) do k
        :($k = $(first(ctx.scope[k])))
    end
end

function and_expr(lhs, rhs)
    if lhs == true
        return rhs
    elseif rhs == true
        return lhs
    else
        return Expr(:block, :($lhs && $rhs))
    end
end

and_expr(lhs, rhs, more...) = and_expr(and_expr(lhs, rhs), more...)
