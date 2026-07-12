function derive_impl(::Val{:Eq}, mod::Module, type::Module)
    jl = JLIfElse()
    for variant_type in Data.variants(type.Type)
        jl[:(vtype <: $variant_type)] = eq_derive_variant_field(
            :($Base.:(==)), variant_type
        )
    end
    jl.otherwise = quote
        return false
    end

    jl_isequal = JLIfElse()
    for variant_type in Data.variants(type.Type)
        jl_isequal[:(vtype <: $variant_type)] = eq_derive_variant_field(
            :($Base.isequal), variant_type
        )
    end
    jl_isequal.otherwise = quote
        return false
    end

    return quote
        Base.@constprop :aggressive function $Base.:(==)(
            lhs::EqT, rhs::EqT
        ) where {EqT<:$type.Type}
            $Data.variant_type(lhs) == $Data.variant_type(rhs) || return false
            vtype = $Data.variant_type(lhs)
            return $(codegen_ast(jl))
        end

        Base.@constprop :aggressive function $Base.isequal(
            lhs::EqT, rhs::EqT
        ) where {EqT<:$type.Type}
            $Data.variant_type(lhs) == $Data.variant_type(rhs) || return false
            vtype = $Data.variant_type(lhs)
            return $(codegen_ast(jl_isequal))
        end
    end
end

function derive_impl(::Val{:Eq}, mod::Module, type::Union{DataType,UnionAll})
    return quote
        Base.@constprop :aggressive function $Base.:(==)(lhs::$type, rhs::$type)
            return $(eq_derive_struct_field(:($Base.:(==)), type))
        end

        Base.@constprop :aggressive function $Base.isequal(lhs::$type, rhs::$type)
            return $(eq_derive_struct_field(:($Base.isequal), type))
        end
    end
end

function eq_derive_struct_field(func, type::Union{DataType,UnionAll})
    names = fieldnames(type)
    types = fieldtypes(type)
    cache_indices = findall(t -> t <: Hash.Cache, collect(types))
    length(cache_indices) > 1 && error("Only one field of type Hash.Cache is allowed")

    body = Expr(:block)
    for (field, fieldtype) in zip(names, types)
        fieldtype <: Hash.Cache && continue
        @gensym lhs_value rhs_value
        push!(
            body.args,
            quote
                $lhs_value = $Base.getfield(lhs, $(QuoteNode(field)))
                $rhs_value = $Base.getfield(rhs, $(QuoteNode(field)))
                $func($lhs_value, $rhs_value) || return false
            end,
        )
    end

    isempty(cache_indices) && return quote
        $body
        return true
    end

    cache_field = names[first(cache_indices)]
    @gensym lhs_hash rhs_hash
    return quote
        $lhs_hash = $Base.getfield(lhs, $(QuoteNode(cache_field)))
        $rhs_hash = $Base.getfield(rhs, $(QuoteNode(cache_field)))
        if $lhs_hash.is_set && $rhs_hash.is_set
            return $lhs_hash[] == $rhs_hash[]
        else
            $body
            return true
        end
    end
end # eq_derive_struct_field

function eq_derive_variant_field(func, variant_type)
    cache_indices = findall(Data.variant_fieldtypes(variant_type)) do type
        return type <: Hash.Cache
    end
    length(cache_indices) > 1 && error("Only one field of type Hash.Cache is allowed")

    body = expr_map(
        Data.variant_fieldnames(variant_type), Data.variant_fieldtypes(variant_type)
    ) do field, type
        type <: Hash.Cache && return nothing
        lhs_value = gensym(:lhs_value)
        rhs_value = gensym(:rhs_value)
        return quote
            $lhs_value = $Base.getproperty(lhs, $(QuoteNode(field)))
            $rhs_value = $Base.getproperty(rhs, $(QuoteNode(field)))
            $func($lhs_value, $rhs_value) || return false
        end # quote
    end

    isempty(cache_indices) && return quote
        $body
        return true
    end

    hash_cache_idx = first(cache_indices)
    @gensym lhs_hash rhs_hash
    quote
        $lhs_hash = $Data.variant_getfield(lhs, $variant_type, $hash_cache_idx)
        $rhs_hash = $Data.variant_getfield(rhs, $variant_type, $hash_cache_idx)

        if $lhs_hash.is_set && $rhs_hash.is_set
            return $lhs_hash[] == $rhs_hash[]
        else
            $body
            return true
        end
    end
end # eq_derive_variant_field
