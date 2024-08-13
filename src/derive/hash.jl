module Hash

mutable struct Cache
    value::UInt64
    is_set::Bool
end

Cache() = Cache(0, false)

Base.getindex(cache::Cache) = cache.value
function Base.setindex!(cache::Cache, value)
    cache.value = value
    cache.is_set = true
    return cache
end

function find_cache(types)::Union{Int,Nothing}
    cache_idx = nothing
    for (idx, type) in enumerate(types)
        if type === Cache
            isnothing(cache_idx) || error("Only one field of type Hash.Cache is allowed")
            cache_idx = idx
        end
    end
    return cache_idx
end

end # Hash

function derive_impl(::Val{:Hash}, mod::Module, type::Module)
    jl = JLIfElse()
    for variant_type in Data.variants(type.Type)
        variant_type_hash = hash(variant_type)
        body = quote
            h0 = $Base.hash(h, $variant_type_hash)
        end
        fieldtypes = Data.variant_fieldtypes(variant_type)
        last_hash = 0
        for (idx, (name, type)) in
            enumerate(zip(Data.variant_fieldnames(variant_type), fieldtypes))
            type === Hash.Cache && continue
            val = xcall(Data, :variant_getfield, :x, variant_type, QuoteNode(name))
            push!(body.args, LineNumberNode(@__LINE__() + 1, @__FILE__)) # so we have error message addressed here
            push!(
                body.args, :($(Symbol(:h, idx)) = $Base.hash($val, $(Symbol(:h, idx - 1))))
            )
            last_hash += 1
        end
        push!(body.args, LineNumberNode(@__LINE__() + 1, @__FILE__)) # so we have error message addressed here
        push!(body.args, Symbol(:h, last_hash)) # fix block return value to last value

        cache_idx = Hash.find_cache(fieldtypes)
        jl[:($Data.isa_variant(x, $variant_type))] = if isnothing(cache_idx)
            quote
                return $body
            end
        else
            @gensym cache
            f_cache = :($Data.variant_getfield(x, $variant_type, $cache_idx))
            quote
                $cache = $f_cache
                if !$cache.is_set
                    $cache[] = $body
                end
                return $cache[]
            end # quote
        end # jl[:(vtype == $variant_type)]
    end # for variant_type in variants(type.Type)

    return quote
        Base.@constprop :aggressive function $Base.hash(x::$type.Type, h::UInt)
            h = hash($(hash(type.Type)), h)
            return $(codegen_ast(jl))
        end
    end
end # derive_impl
