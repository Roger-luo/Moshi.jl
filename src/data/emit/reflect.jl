@pass function emit_is_data_type(info::EmitInfo)
    return quote
        function $Data.is_data_type(::$Base.Type{$(info.type.name)})
            return true
        end

        function $Data.is_data_type(::$Base.Type{$(info.type.variant)})
            return true
        end

        function $Data.is_data_type(::$(info.type.name))
            return true
        end

        function $Data.is_data_type(::$(info.type.variant))
            return true
        end
    end
end

@pass function emit_data_type_module(info::EmitInfo)
    return quote
        $Base.@constprop :aggressive function $Data.data_type_module(
            ::$Base.Type{$(info.type.name)}
        )
            return $(info.def.name)
        end

        $Base.@constprop :aggressive function $Data.data_type_module(
            ::$Base.Type{$(info.type.variant)}
        )
            return $(info.def.name)
        end

        $Base.@constprop :aggressive function $Data.data_type_module(
            ::$(info.type.name)
        )
            return $(info.def.name)
        end

        $Base.@constprop :aggressive function $Data.data_type_module(
            ::$(info.type.variant)
        )
            return $(info.def.name)
        end
    end
end

@pass function emit_data_type_name(info::EmitInfo)
    return quote
        $Base.@constprop :aggressive function $Data.data_type_name(
            ::$Base.Type{$(info.type.name)}
        )
            return $(QuoteNode(info.def.name))
        end

        $Base.@constprop :aggressive function $Data.data_type_name(
            ::$Base.Type{$(info.type.variant)}
        )
            return $(QuoteNode(info.def.name))
        end

        $Base.@constprop :aggressive function $Data.data_type_name(
            ::$(info.type.name)
        )
            return $(QuoteNode(info.def.name))
        end

        $Base.@constprop :aggressive function $Data.data_type_name(
            ::$(info.type.variant)
        )
            return $(QuoteNode(info.def.name))
        end
    end
end

@pass function emit_variant_name(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        return QuoteNode(variant.name)
    end

    return quote
        $Base.@constprop :aggressive function $Data.variant_name(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variant_name(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

@pass function emit_variants(info::EmitInfo)
    variant_types = map(info.def.variants) do variant
        vinfo = info.variants[variant]::VariantInfo
        :($(info.type.variant)($(vinfo.tag)))
    end
    body = xtuple(variant_types...)

    return quote
        $Base.@constprop :aggressive function $Data.variants(::$(info.type.name))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variants(
            ::$Base.Type{$(info.type.name)}
        )
            return $body
        end
    end
end

@pass function emit_variant_kind(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        return QuoteNode(variant.kind)
    end

    return quote
        $Base.@constprop :aggressive function $Data.variant_kind(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variant_kind(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

@pass function emit_variant_type(info::EmitInfo)
    return quote
        $Base.@constprop :aggressive function $Data.variant_type(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $(info.type.variant)(tag)
        end
    end
end

@pass function emit_variant_tag(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo
        return vinfo.tag
    end
    return quote
        $Base.@constprop :aggressive function $Data.variant_tag(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variant_tag(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

@pass function emit_is_singleton_on_instance(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo
        variant.kind == Singleton && return true
        return false
    end
    return quote
        $Base.@constprop :aggressive function $Data.is_singleton(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end
    end
end

@pass function emit_is_singleton_on_variant_type(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo
        variant.kind == Singleton && return true
        return false
    end
    return quote
        $Base.@constprop :aggressive function $Data.is_singleton(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

# variant_fieldname(variant_instance, idx::Int)::Symbol = invalid_method()
# variant_fieldnames(variant_instance)::Tuple = invalid_method()
# variant_nfields(variant_instance)::Int = invalid_method()
# variant_fieldtype(variant_instance, idx::Int)::Symbol = invalid_method()
# variant_fieldtypes(variant_instance, idx::Int)::Tuple = invalid_method()

@pass function emit_variant_fieldnames(info::EmitInfo)
    body = emit_variant_fieldnames_body(info)
    return quote
        $Base.@constprop :aggressive function $Data.variant_fieldnames(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variant_fieldnames(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

@pass function emit_variant_fieldtypes(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        variant.kind === Singleton && return :(())

        names = map(vinfo) do f::FieldInfo
            f.type
        end
        return xtuple(names...)
    end

    return quote
        $Base.@constprop :aggressive function $Data.variant_fieldtypes(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variant_fieldtypes(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

@pass function emit_variant_nfields(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo::VariantInfo
        variant.kind === Singleton && return :(())
        return length(variant.fields)
    end

    return quote
        $Base.@constprop :aggressive function $Data.variant_nfields(
            type::$(info.type.name)
        )
            $(emit_get_data_tag(info))
            return $body
        end

        $Base.@constprop :aggressive function $Data.variant_nfields(
            variant_type::$(info.type.variant)
        )
            tag = variant_type.tag
            return $body
        end
    end
end

@pass function emit_variant_type_cmp(info::EmitInfo)
    quote
        function $Base.:(==)(lhs::$(info.type.variant), rhs::$(info.type.variant))
            return lhs.tag == rhs.tag
        end
    end
end
