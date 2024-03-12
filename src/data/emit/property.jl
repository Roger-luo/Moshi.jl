@pass function emit_getproperty(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        emit_variant_getproperty(info, variant, vinfo)
    end
    jl = emit_getproperty_fn(info)
    push!(jl.args, :(f::Symbol))
    jl.body = quote
        $(emit_get_data_tag(info))
        $body
    end
    return codegen_ast(jl)
end

@pass function emit_getproperty_num(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        emit_variant_getproperty_num(info, variant, vinfo)
    end

    jl = emit_getproperty_fn(info)
    push!(jl.args, :(f::Int))
    jl.body = quote
        $(emit_get_data_tag(info))
        $body
    end
    return codegen_ast(jl)
end

@pass function emit_propertynames(info::EmitInfo)
    return quote
        function $Base.propertynames(type::$(info.type.name))
            $(emit_get_data_tag(info))
            return $(emit_variant_fieldnames_body(info))
        end
    end
end

@pass function emit_variant_getfield(info::EmitInfo)
    return expr_map(info.variants) do (variant, vinfo)
        return quote
            function $Data.variant_getfield(
                type::$(info.type.name), ::$Base.Val{$(vinfo.tag)}, f::Symbol
            )
                data = $Core.getfield(type, :data)::$(info.type.storage.name)
                return $(emit_variant_getproperty(info, variant, vinfo))
            end
        end
    end
end

@pass function emit_variant_getfield_num(info::EmitInfo)
    return expr_map(info.variants) do (variant, vinfo)
        return quote
            function $Data.variant_getfield(
                type::$(info.type.name), ::$Base.Val{$(vinfo.tag)}, f::Int
            )
                data = $Core.getfield(type, :data)::$(info.type.storage.name)
                return $(emit_variant_getproperty_num(info, variant, vinfo))
            end
        end
    end
end

function emit_variant_fieldnames_body(info::EmitInfo)
    return foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        variant.kind === Singleton && return :(())
        variant.kind === Anonymous && return xtuple((1:length(variant.fields))...)

        names = map(variant.fields) do f::NamedField
            QuoteNode(f.name)
        end
        return xtuple(names...)
    end
end

function emit_get_data_tag(info::EmitInfo)
    quote
        # storage does not have type params here
        data = $Core.getfield(type, :data)::$(info.type.storage.name)
        tag = data.tag[1]::UInt8
    end
end

function emit_getproperty_fn(info::EmitInfo)
    return JLFunction(; name=:($Base.getproperty), args=[:(type::$(info.type.name))])
end

function emit_variant_getproperty(info::EmitInfo, variant::Variant, vinfo::VariantInfo)
    variant.kind === Named ||
        return :($Core.throw(ArgumentError("cannot access anonymous variant field")))

    jl = JLIfElse()
    for (field::NamedField, finfo::FieldInfo) in zip(variant.fields, vinfo)
        field_name = QuoteNode(field.name)
        jl[:(f === $field_name)] = emit_variant_getfield_from_storage(info, finfo)
    end
    jl.otherwise = quote
        return $Core.throw($Base.ArgumentError("invalid field name: $f"))
    end
    return codegen_ast(jl)
end

function emit_variant_getproperty_num(info::EmitInfo, variant::Variant, vinfo::VariantInfo)
    jl = JLIfElse()
    for (idx, finfo::FieldInfo) in enumerate(vinfo)
        jl[:(f === $idx)] = emit_variant_getfield_from_storage(info, finfo)
    end
    jl.otherwise = quote
        return $Core.throw($Base.ArgumentError("invalid field index: $f"))
    end

    return codegen_ast(jl)
end

function emit_variant_getfield_from_storage(::EmitInfo, finfo::FieldInfo)
    finfo.is_bitstype && return quote
        return $Data.unsafe_padded_reinterpret(
            $(finfo.type), data.bits[$(finfo.index)]
        )::$(finfo.type)
    end

    quote
        return data.ptrs[$(finfo.index)]::$(finfo.type)
    end
end
