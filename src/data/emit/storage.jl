@pass 1 function emit_variant_storage(info::EmitInfo)
    return expr_map(
        x -> emit_each_variant_storage(info, x), info.storages; skip_nothing=true
    )
end

function emit_each_variant_storage(info::EmitInfo, storage::StorageInfo)
    jl = if storage.parent.kind == Singleton
        if info.def.ismutable
            throw(ArgumentError("Cannot create singleton variants for mutable ADTs"))
        end
        JLStruct(; typevars=info.whereparams, name=storage.name)
    elseif storage.parent.kind == Anonymous
        fields = [
            JLField(;
                name=gensym(:field), type=storage.types[i], line=storage.parent.source
            ) for (i, field) in enumerate(storage.parent.fields)
        ]
        JLStruct(; typevars=info.whereparams, name=storage.name, fields, ismutable=info.def.ismutable)
    else
        fields = [
            JLField(; name=field.name, type=storage.types[i], line=field.source, isconst=field.isconst) for
            (i, field) in enumerate(storage.parent.fields)
        ]
        JLStruct(; typevars=info.whereparams, name=storage.name, fields, ismutable=info.def.ismutable)
    end
    return codegen_ast(jl)
end
