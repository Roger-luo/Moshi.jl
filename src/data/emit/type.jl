@pass 1 function emit_variant(info::EmitInfo)
    return quote
        struct $(info.type.variant)
            tag::UInt8
        end
    end
end

@pass 1 function emit_storage(info::EmitInfo)
    return quote
        struct $(info.type.storage.name)
            tag::$Base.NTuple{$(info.type.storage.size.tag),UInt8}
            bits::$Base.NTuple{$(info.type.storage.size.bits),UInt8}
            ptrs::$Base.NTuple{$(info.type.storage.size.ptrs),Any}
        end
    end
end

@pass 2 function emit_type(info::EmitInfo)
    if isnothing(info.def.supertype)
        return quote
            struct $(info.type.name)
                data::$(info.type.storage.name)
            end
        end
    else
        return quote
            struct $(info.type.name) <: $(info.def.mod).$(info.def.supertype)
                data::$(info.type.storage.name)
            end
        end
    end
end
