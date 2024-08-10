@pass 10 function emit_public(info::EmitInfo)
    VERSION > v"1.11-" || return nothing
    return expr_map(info.storages) do storage
        # see JuliaLang/julia/issues/51450
        Expr(:public, storage.parent.name)
    end
end
