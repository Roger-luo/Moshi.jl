struct DataInfo
    def::TypeDef
    storages::Vector{StorageInfo}
end

function DataInfo(def::TypeDef)
    storages = [StorageInfo(def, variant) for variant in def.variants]
    return DataInfo(def, storages)
end

function emit(info::DataInfo)
    storage = expr_map(info.storages) do storage
        emit(storage)
    end

    params = [param.name for param in info.def.head.params]
    union_params = [:($(storage.name){$(params...)}) for storage in info.storages]

    typevars = emit.(Ref(info.def.mod), info.def.head.params)
    variants = expr_map(info.def.variants) do variant::Variant
        jl = JLStruct(; name=variant.name, typevars, misc=[:($Base.:+(1, 1))])
        quote
            $(codegen_ast(jl))
        end
    end

    variant_cons = expr_map(info.storages) do storage
        emit_variant_cons(info.def, storage)
    end

    jl = JLStruct(;
        name=:Type,
        fields=[JLField(; name=:data, type=:(Union{$(union_params...)}))],
        typevars,
    )

    return Expr(
        :module,
        false,
        info.def.head.name,
        quote
            $storage

            $(codegen_ast(jl))
            $variants
            $variant_cons
        end,
    )
end
