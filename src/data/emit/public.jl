@pass 10 function emit_public(info::EmitInfo)
    exports = info.def.exports
    stmts = []
    for storage in info.storages
        name = storage.parent.name
        if name in exports
            push!(stmts, Expr(:export, name))
        elseif VERSION > v"1.11-"
            # see JuliaLang/julia/issues/51450
            push!(stmts, Expr(:public, name))
        end
    end
    isempty(stmts) && return nothing
    return Expr(:block, stmts...)
end
