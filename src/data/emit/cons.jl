@pass function emit_variant_cons(info::EmitInfo)
    return expr_map(x -> emit_each_variant_cons(info, x), info.storages; skip_nothing=true)
end

function emit_each_variant_cons(info::EmitInfo, storage::StorageInfo)
    args = if storage.parent.kind == Singleton
        []
    elseif storage.parent.kind == Anonymous
        [Symbol(i) for i in 1:length(storage.parent.fields)]
    else
        map(storage.parent.fields) do field::NamedField
            field.name
        end
    end

    return quote
        $Base.@constprop :aggressive function $(storage.variant_head)(
            $(args...)
        ) where {$(info.whereparams...)}
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(args...)))
        end
    end
end

@pass function emit_variant_kw_cons(info::EmitInfo)
    return expr_map(
        x -> emit_each_variant_kw_cons(info, x), info.storages; skip_nothing=true
    )
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
    return expr_map(
        x -> emit_each_variant_cons_inferred(info, x), info.storages; skip_nothing=true
    )
end

function emit_each_variant_cons_inferred(info::EmitInfo, storage::StorageInfo)
    isempty(info.params) && return nothing # no type parameters
    storage.parent.kind == Singleton && return nothing

    is_inferrable(info.params, storage) || return nothing

    if storage.parent.kind == Anonymous
        args = [:($(Symbol(i))::$(type)) for (i, type) in enumerate(storage.annotations)]
        inputs = [Symbol(i) for i in 1:length(storage.parent.fields)]
    else
        args = [
            :($(field.name)::$(type)) for
            (field, type) in zip(storage.parent.fields, storage.annotations)
        ]
        inputs = [field.name for field in storage.parent.fields]
    end

    jl = JLFunction(;
        name=storage.parent.name,
        args,
        info.whereparams,
        body=quote
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(inputs...)))
        end,
    )

    return codegen_ast(jl)
end

function is_inferrable(params::Vector{Symbol}, storage::StorageInfo)
    return all(is_inferrable(param, storage) for param in params)
end

function is_inferrable(param::Symbol, storage::StorageInfo)
    return any(is_inferrable(param, each) for each in storage.annotations)
end

function is_inferrable(param::Symbol, type)
    if type isa Symbol
        return param == type
    elseif Meta.isexpr(type, :curly)
        return any(is_inferrable(param, each) for each in type.args[2:end])
    else
        return false
    end
end

# special singleton constructor with adaptive type parameters

@pass function emit_variant_cons_singleton_bottom(info::EmitInfo)
    isempty(info.params) && return nothing # no type parameters
    return expr_map(info.storages; skip_nothing=true) do storage::StorageInfo
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
