@pass function emit_getproperty(info::EmitInfo{GeneratedTypeSize})
    prepare_getters = emit_variant_field_getters(info) do variant::Variant
        variant.kind === :struct
    end
    generated = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        variant.kind === :singleton && return :(throw(ArgumentError("singleton does not have fields")))
        variant.kind === :call && return :(throw(ArgumentError("cannot access anonymous variant field")))
        foreach_named_field(variant, vinfo)
    end
    generated_body = quote
        $(emit_get_data_tag(info))
        $(generated)
    end

    jl = emit_getproperty_fn(info)
    push!(jl.args, :(f::Symbol))
    jl.body = quote
        $(emit_generated_size(info))
        $(emit_generated_index(info))
        $prepare_getters
        $(Expr(:quote, generated_body))
    end
    codegen_ast(jl)
end

@pass function emit_propertynames(info::EmitInfo{GeneratedTypeSize})
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

    generated = quote
        $(emit_get_data_tag(info))
        $body
    end
    jl.body = quote
        $(emit_generated_size(info))
        $(emit_generated_index(info))
        $(Expr(:quote, generated))
    end
    return codegen_ast(jl)
end

@pass function emit_getproperty_num(info::EmitInfo{GeneratedTypeSize})
    prepare_getters = emit_variant_field_getters(info) do variant::Variant
        variant.kind === :struct || variant.kind === :call
    end

    generated = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        variant.kind === :singleton && return :(throw(ArgumentError("singleton does not have fields")))
        foreach_field(variant, vinfo)
    end
    generated_body = quote
        $(emit_get_data_tag(info))
        $(generated)
    end

    jl = emit_getproperty_fn(info)
    push!(jl.args, :(f::Int))
    jl.body = quote
        $(emit_generated_size(info))
        $(emit_generated_index(info))
        $prepare_getters
        $(Expr(:quote, generated_body))
    end
    return codegen_ast(jl)
end

function foreach_field(variant::Variant, vinfo::VariantInfo)
    jl = JLIfElse()
    for (idx, finfo::FieldInfo) in enumerate(vinfo)
        jl[:(f === $idx)] = Expr(:$, finfo.get_expr)
    end
    jl.otherwise = :(throw(ArgumentError("invalid field index: $(f)")))
    return codegen_ast(jl)
end

function foreach_named_field(variant::Variant, vinfo::VariantInfo)
    jl = JLIfElse()
    for (f, finfo::FieldInfo) in zip(variant.fields, vinfo)
        jl[:(f === $(QuoteNode(f.name)))] = Expr(:$, finfo.get_expr)
    end
    jl.otherwise = :(throw(ArgumentError("invalid field name: $(f)")))
    return codegen_ast(jl)
end

function emit_variant_field_getters(cond, info::EmitInfo{GeneratedTypeSize})
    expr_map(keys(info.variants), values(info.variants)) do variant, vinfo
        cond(variant) || return Expr(:block)
        expr_map(vinfo) do f::FieldInfo
            bits = :($Data.unsafe_padded_reinterpret($(f.expr), data.bits[$(Expr(:$, f.index))])::$(f.expr))
            ptrs = :(data.ptrs[$(Expr(:$, f.index))]::$(f.expr))
            quote
                $(f.get_expr) = if isbitstype($(f.expr))
                    $(Expr(:quote, bits))
                else
                    $(Expr(:quote, ptrs))
                end
            end
        end
    end
end

function emit_getproperty_fn(info::EmitInfo{GeneratedTypeSize})
    jl = invoke(emit_getproperty_fn, Tuple{EmitInfo}, info)
    jl.generated = true
    return jl
end

function emit_get_data_tag(info::EmitInfo{GeneratedTypeSize})
    quote
        data = $Core.getfield(type, :data)::$(info.type.storage.full_cons)
        tag = data.tag[1]::UInt8
    end
end
