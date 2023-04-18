function emit_generated_index(info::EmitInfo{GeneratedTypeSize})
    @gensym start stop ptr
    bits_index = Symbol[]; ptrs_index = Symbol[]
    return expr_map(values(info.variants)) do vinfo
        vbody = expr_map(vinfo) do f::FieldInfo
            quote
                if $Base.isbitstype($(f.expr))
                    $stop = $start + sizeof($(f.expr))
                    $(f.index) = $start+1:$stop
                    $start = $stop
                else
                    $(f.index) = $ptr
                    $ptr += 1
                end
            end
        end

        return quote
            $start = 0; $stop = 0; $ptr = 1
            $vbody
        end
    end
end

function emit_generated_size(info::EmitInfo)
    type_bits = Symbol[]; type_ptrs = Symbol[]
    body = expr_map(enumerate(info.def.variants)) do (idx, variant)
        variant.kind === :singleton && return
        @gensym bits ptrs
        push!(type_bits, bits)
        push!(type_ptrs, ptrs)
        ret = quote
            $bits = 0; $ptrs = 0
        end
        for field in variant.fields
            type = field.type
            push!(ret.args, quote
                if $Base.isbitstype($type)
                    $bits += sizeof($type)
                else
                    $ptrs += 1
                end
            end)
        end
        return ret
    end
    @gensym total
    return quote
        $body
        $(info.type.storage.size.bits_byte) = max($(type_bits...))
        $(info.type.storage.size.ptrs_byte) = max($(type_ptrs...))
        $total = $(info.type.storage.size.bits_byte) + $(info.type.storage.size.ptrs_byte)
        $(info.type.storage.size.tag_byte) = if $total <= 1
            1
        elseif $total <= 2
            2
        elseif $total <= 4
            4
        else
            sizeof(UInt)
        end
    end
end

include("cons.jl")
include("property.jl")
