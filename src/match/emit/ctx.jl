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
        # NOTE: let's just not support 1.8-
        val_expr = xtuple(values...)
        push!(stmts, :($Base.allequal($val_expr)))
    end
    return foldl(and_expr, stmts; init=true)
end

function emit_bind_match_values(ctx::PatternContext)
    return map(collect(keys(ctx.scope))) do k
        :($k = $(first(ctx.scope[k])))
    end
end

and_expr(lhs, rhs) = quote
    $lhs && $rhs
end
