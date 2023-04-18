@pass 3 function emit_storage_cons(info::EmitInfo{GeneratedTypeSize})
    @gensym tag bits ptrs
    generated = quote
        $(Expr(:$, :tag)) = $(Expr(:$, tag))
        $(Expr(:$, :bits)) = $Data.unsafe_padded_reinterpret(NTuple{$(Expr(:$, info.type.storage.size.bits_byte)), UInt8}, bits)
        $(Expr(:$, :ptrs)) = $Data.padded_tuple_any(Val($(Expr(:$, info.type.storage.size.ptrs_byte))), ptrs)
        $(info.type.storage.full_cons)($(Expr(:$, :tag)), $(Expr(:$, :bits)), $(Expr(:$, :ptrs)))
    end
    quote
        @generated function $(info.type.storage.cons)(tag::UInt8, bits::Tuple, ptrs::Tuple) where {$(info.type.bounded_vars...)}
            $(emit_generated_size(info))

            total_byte = $(info.type.storage.size.bits_byte) + $(info.type.storage.size.ptrs_byte)
            $(info.type.storage.size.tag_byte) = if total_byte <= 1
                1
            elseif total_byte <= 2
                2
            elseif total_byte <= 4
                4
            else
                sizeof(UInt)
            end

            @gensym tag bits ptrs
            $tag = Expr(:tuple, :tag, (zero(UInt8) for _ in 1:$(info.type.storage.size.tag_byte)-1)...)
            return $(Expr(:quote, generated))
        end
    end
end

@pass 4 function emit_cons(info::EmitInfo{GeneratedTypeSize})
    extracts = Dict{Variant, Tuple{Symbol, Symbol}}()
    body = expr_map(keys(info.variants), values(info.variants)) do variant::Variant, vinfo::VariantInfo
        @gensym bits ptrs
        extracts[variant] = (bits, ptrs)
        body = expr_map(vinfo) do f::FieldInfo
            quote
                if isbitstype($(f.expr))
                    push!($bits.args, $(QuoteNode(f.var)))
                else
                    push!($ptrs.args, $(QuoteNode(f.var)))
                end
            end
        end
        quote
            $bits, $ptrs = Expr(:tuple), Expr(:tuple)
            $body
        end
    end

    generated = foreach_variant(info, :(type.tag)) do variant::Variant, vinfo::VariantInfo
        bits, ptrs = extracts[variant]
        quote
            $(emit_extract(variant, vinfo))
            return $(info.type.name.cons)(
                $(info.type.storage.cons)(
                    $(vinfo.tag), $(Expr(:$, bits)), $(Expr(:$, ptrs))
                )
            )
        end
    end

    quote
        @generated function (type::$(info.type.variant.cons))(args...; kwargs...) where {$(info.type.bounded_vars...)}
            $(emit_generated_size(info))
            $body
            $(Expr(:quote, generated))
        end
    end
end

function emit_extract(variant::Variant, vinfo::VariantInfo)
    variant.kind === :singleton && return Expr(:block)
    positional = expr_map(enumerate(vinfo)) do (idx, f)
        :($(f.var) = $Base.convert($(f.expr), args[$idx]))
    end
    variant.kind === :call && return positional
    kwargs = expr_map(variant.fields, vinfo) do f::NamedField, finfo::FieldInfo
        val = if f.default === no_default
            msg = "missing keyword argument: $(f.name)"
            quote
                haskey(kwargs, $(QuoteNode(f.name))) || $Core.throw($Base.ArgumentError($msg))
                $Base.convert($(finfo.expr), kwargs[$(QuoteNode(f.name))])
            end
        else
            quote
                $Base.convert(
                    $(finfo.expr),
                    $Base.get(kwargs, $(QuoteNode(f.name)), $(f.default))
                )
            end
        end
        :($(finfo.var) = $val)
    end
    return quote
        if isempty(kwargs)
            $positional
        elseif isempty(args)
            $kwargs
        else
            $Core.throw($Base.ArgumentError("cannot mix positional and keyword arguments"))
        end
    end
end
