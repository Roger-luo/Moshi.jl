function decons_guard(info::PatternInfo, pat::Pattern.Type)
    return function guard(_)
        return replace_guard_vars(info, pat.:1)
    end
end

function replace_guard_vars(info::PatternInfo, cond)
    if cond isa Symbol
        haskey(info.scope, cond) && return first(info.scope[cond])
        return cond
    end
    cond isa Expr || return cond
    return Expr(cond.head, map(x -> replace_guard_vars(info, x), cond.args)...)
end
