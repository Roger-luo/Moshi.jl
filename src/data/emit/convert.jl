@pass function emit_singleton_convert(info::EmitInfo)
    return quote
        function $Base.convert(
            ::Type{$(info.type.name.cons)},
            x::$(info.type.variant.cons)
            ) where {$(info.type.bounded_vars...)}
            $Data.is_singleton(x) || throw(ArgumentError("cannot convert non-singleton variant to singleton type"))
            return x()
        end
    end
end
