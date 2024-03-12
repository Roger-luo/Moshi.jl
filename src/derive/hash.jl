function derive_impl(::Val{:Hash}, mod::Module, type::Module)
    jl = JLIfElse()
    for variant_type in variants(type.Type)
        body = :h
        fieldtypes = variant_fieldtypes(variant_type)
        for (name, type) in zip(variant_fieldnames(variant_type), fieldtypes)
            type === Hash.Cache && continue
            val = xcall(
                Data, :variant_getfield, :x, Val(variant_type.tag), QuoteNode(name)
            )
            body = :(hash($val, $body))
        end

        cache_idx = findfirst(fieldtypes) do type
            type === Hash.Cache
        end

        jl[:(vtype == $variant_type)] = if isnothing(cache_idx) # no hash cache
            quote
                return $body
            end
        else
            @gensym cache
            f_cache = xcall(
                Data, :variant_getfield, :x, Val(variant_type.tag), cache_idx
            )
            quote
                $cache = $f_cache
                if !$cache.is_set
                    $cache[] = $body
                end
                return $cache[]
            end # quote
        end # jl[:(vtype == $variant_type)]
    end # for variant_type in variants(type.Type)
    jl.otherwise = quote
        error("unreachable")
    end

    return quote
        Base.@constprop :aggressive function $Base.hash(x::$type.Type, h::UInt)
            h = hash($(hash(type)), h)
            h = hash($Data.variant_tag(x), h)
            vtype = $Data.variant_type(x)
            return $(codegen_ast(jl))
        end
    end
end
