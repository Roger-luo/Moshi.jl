@pass 1 function emit_variant(info::EmitInfo)
    if info.type.storage.size isa TypeSize
        return quote
            struct $(info.type.variant.full)
                tag::UInt8
            end
        end
    end

    return quote
        struct $(info.type.variant.full)
            tag::UInt8
        end
    end
end

@pass 1 function emit_storage(info::EmitInfo)
    return quote
        struct $(info.type.storage.full_type)
            tag::NTuple{$(info.type.storage.size.tag_byte), UInt8}
            bits::NTuple{$(info.type.storage.size.bits_byte), UInt8}
            ptrs::NTuple{$(info.type.storage.size.ptrs_byte), Any}
        end
    end
end

@pass 2 function emit_type(info::EmitInfo)
    if isnothing(info.def.supertype)
        return quote
            struct $(info.type.name.full)
                data::$(info.type.storage.cons)
            end
        end
    else
        return quote
            struct $(info.type.name.full) <: $(info.def.supertype)
                data::$(info.type.storage.cons)
            end
        end
    end
end
