@pass function emit_getproperty(info::EmitInfo{TypeSize})
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

@pass function emit_getproperty_num(info::EmitInfo{TypeSize})
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

@pass function emit_propertynames(info::EmitInfo{TypeSize})
    jl = emit_getproperty_fn(info)
    jl.name = :($Base.propertynames)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        variant.kind === :singleton && return :(())
        variant.kind === :call && return xtuple((1:length(variant.fields))...)

        names = map(variant.fields) do f::NamedField
            QuoteNode(f.name)
        end
        return xtuple(names...)
    end

    jl.body = quote
        $(emit_get_data_tag(info))
        $body
    end
    return codegen_ast(jl)
end

function emit_get_data_tag(info::EmitInfo{TypeSize})
    quote
        # storage does not have type params here
        data = getfield(type, :data)::$(info.type.storage.name)
        tag = data.tag[1]::UInt8
    end
end

function emit_getproperty_fn(info::EmitInfo)
    JLFunction(;
        name = :($Base.getproperty),
        args = [
            :(type::$(info.type.name.cons)),
        ],
        whereparams = isempty(info.type.bounded_vars) ? nothing : info.type.bounded_vars,
    )
end

function emit_variant_getproperty(info::EmitInfo{TypeSize}, variant::Variant, vinfo::VariantInfo)
    variant.kind === :struct || return :(throw(ArgumentError("cannot access anonymous variant field")))

    jl = JLIfElse()
    for (field::NamedField, finfo::FieldInfo) in zip(variant.fields, vinfo)
        field_name = QuoteNode(field.name)
        jl[:(f === $field_name)] = emit_variant_getfield(info, finfo)
    end
    jl.otherwise = quote
        return $Core.throw($Base.ArgumentError(
            "invalid field name: $f"
        ))
    end
    codegen_ast(jl)
end

function emit_variant_getproperty_num(info::EmitInfo{TypeSize}, variant::Variant, vinfo::VariantInfo)
    jl = JLIfElse()
    for (idx, finfo::FieldInfo) in enumerate(vinfo)
        jl[:(f === $idx)] = emit_variant_getfield(info, finfo)
    end
    jl.otherwise = quote
        return $Core.throw($Base.ArgumentError(
            "invalid field index: $f"
        ))
    end

    codegen_ast(jl)
end

function emit_variant_getfield(::EmitInfo{TypeSize}, finfo::FieldInfo)
    finfo.is_bitstype && return quote
        return $Data.unsafe_padded_reinterpret(
            $(finfo.expr), data.bits[$(finfo.index)]
        )::$(finfo.expr)
    end

    quote
        return data.ptrs[$(finfo.index)]::$(finfo.expr)
    end
end
