function decons(::Type{Pattern.Guard}, ctx::PatternContext, pat::Pattern.Type)
    return function guard(_)
        return replace_guard_vars(ctx, pat.:1)
    end
end

function replace_guard_vars(ctx::PatternContext, cond)
    if cond isa Symbol
        haskey(ctx.scope, cond) && return first(ctx.scope[cond])
        return cond
    end
    cond isa Expr || return cond
    return Expr(cond.head, map(x -> replace_guard_vars(ctx, x), cond.args)...)
end
