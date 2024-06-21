@pass function emit_variant_cons(info::EmitInfo)
    return expr_map(x -> emit_each_variant_cons(info, x), info.storages)
end

function emit_each_variant_cons(info::EmitInfo, storage::StorageInfo)
    jl = if storage.parent.kind == Singleton
        JLFunction(;
            name=Expr(:curly, storage.parent.name, info.params...),
            info.whereparams,
            body=:(return Type{$(info.params...)}($(storage.name){$(info.params...)}())),
        )
    elseif storage.parent.kind == Anonymous
        args = [Symbol(i) for i in 1:length(storage.parent.fields)]
        JLFunction(;
            name=Expr(:curly, storage.parent.name, info.params...),
            args=[Symbol(i) for (i, field) in enumerate(storage.parent.fields)],
            info.whereparams,
            body=:(
                return Type{$(info.params...)}(
                    $(storage.name){$(info.params...)}($(args...))
                )
            ),
        )
    else
        args = [field.name for field in storage.parent.fields]
        JLFunction(;
            name=Expr(:curly, storage.parent.name, info.params...),
            args=[field.name for field in storage.parent.fields::Vector{NamedField}],
            info.whereparams,
            body=:(
                return Type{$(info.params...)}(
                    $(storage.name){$(info.params...)}($(args...))
                )
            ),
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
        name=Expr(:curly, storage.parent.name, info.params...),
        kwargs=[
            if field.default === no_default
                field.name
            else
                Expr(:kw, field.name, field.default)
            end for field in storage.parent.fields
        ],
        info.whereparams,
        body=:(
            return Type{$(info.params...)}($(storage.name){$(info.params...)}($(args...)))
        ),
    )

    return codegen_ast(jl)
end
