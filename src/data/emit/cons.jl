@pass function emit_variant_cons(info::EmitInfo)
    return expr_map(x -> emit_each_variant_cons(info, x), info.storages)
end

function emit_each_variant_cons(info::EmitInfo, storage::StorageInfo)
    jl = if storage.parent.kind == Singleton
        JLFunction(;
            name=storage.variant_head,
            info.whereparams,
            body=quote
                $(Expr(:meta, :inline))
                return $(info.type_head)($(storage.head)())
            end,
        )
    elseif storage.parent.kind == Anonymous
        args = [Symbol(i) for i in 1:length(storage.parent.fields)]
        JLFunction(;
            name=storage.variant_head,
            args=[Symbol(i) for (i, field) in enumerate(storage.parent.fields)],
            info.whereparams,
            body=quote
                $(Expr(:meta, :inline))
                return $(info.type_head)($(storage.head)($(args...)))
            end,
        )
    else
        args = [field.name for field in storage.parent.fields]
        JLFunction(;
            name=storage.variant_head,
            args=[field.name for field in storage.parent.fields::Vector{NamedField}],
            info.whereparams,
            body=quote
                $(Expr(:meta, :inline))
                return $(info.type_head)($(storage.head)($(args...)))
            end,
        )
    end

    return codegen_ast(jl)
end

@pass function emit_variant_kw_cons(info::EmitInfo)
    return expr_map(x -> emit_each_variant_kw_cons(info, x), info.storages)
end

function emit_each_variant_kw_cons(info::EmitInfo, storage::StorageInfo)
    storage.parent.kind == Named || return nothing

    args = [field.name for field in storage.parent.fields]
    jl = JLFunction(;
        name=storage.variant_head,
        kwargs=[
            if field.default === no_default
                field.name
            else
                Expr(:kw, field.name, Base.eval(info.def.mod, field.default))
            end for field in storage.parent.fields
        ],
        info.whereparams,
        body=quote
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(args...)))
        end,
    )

    return codegen_ast(jl)
end

@pass function emit_variant_cons_inferred(info::EmitInfo)
    return expr_map(x -> emit_each_variant_cons_inferred(info, x), info.storages)
end

function emit_each_variant_cons_inferred(info::EmitInfo, storage::StorageInfo)
    storage.parent.kind == Singleton && return nothing

    types = Set([field.type for field in storage.parent.fields])
    is_inferrable = all(param in types for param in info.params)
    is_inferrable || return nothing
    
    args = if storage.parent.kind == Anonymous
        [:($(Symbol(i))::$(field.type)) for (i, field) in enumerate(storage.parent.fields)]
    else
        [:($(field.name)::$(field.type)) for field in storage.parent.fields]
    end

    jl = JLFunction(;
        name=storage.parent.name,
        args,
        info.whereparams,
        body=quote
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(args...)))
        end,
    )

    return codegen_ast(jl)
end

# special singleton constructor with adaptive type parameters

@pass function emit_variant_cons_singleton_bottom(info::EmitInfo)
    isempty(info.params) && return nothing # no type parameters
    return expr_map(info.storages) do storage::StorageInfo
        storage.parent.kind == Singleton || return nothing

        bottoms = [:(Union{}) for _ in 1:length(info.params)]
        jl = JLFunction(;
            name=storage.parent.name,
            body=quote
                $(Expr(:meta, :inline))
                return Type{$(bottoms...)}($(storage.name){$(bottoms...)}())
            end,
        )

        return codegen_ast(jl)
    end
end
