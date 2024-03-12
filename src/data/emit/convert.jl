@pass function emit_singleton_convert(info::EmitInfo)
    return quote
        function $Base.convert(::$Base.Type{$(info.type.name)}, x::$(info.type.variant))
            $Data.is_singleton(x) || $Core.throw(ArgumentError("x is not a singleton"))
            return x()
        end
    end
end
