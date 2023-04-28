@pass function emit_is_singleton_on_instance(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo
        variant.kind == :singleton && return true
        return false
    end
    return quote
        function $Data.is_singleton(type::$(info.type.name.name))
            $(emit_get_data_tag(info))
            $body
        end
    end
end

@pass function emit_is_singleton_on_variant_type(info::EmitInfo)
    body = foreach_variant(info, :tag) do variant::Variant, vinfo
        variant.kind == :singleton && return true
        return false
    end
    return quote
        function $Data.is_singleton(variant_type::$(info.type.variant.name))
            tag = variant_type.tag
            $body
        end
    end
end
