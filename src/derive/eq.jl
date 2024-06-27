function derive_impl(::Val{:Eq}, mod::Module, type::Module)
    jl = JLIfElse()
    for variant_type in Data.variants(type.Type)
        jl[:(vtype <: $variant_type)] = eq_derive_variant_field(variant_type)
    end
    jl.otherwise = quote
        return false
    end

    return quote
        Base.@constprop :aggressive function $Base.:(==)(lhs::EqT, rhs::EqT) where {EqT <: $type.Type}
            $Data.variant_type(lhs) == $Data.variant_type(rhs) || return false
            vtype = $Data.variant_type(lhs)
            return $(codegen_ast(jl))
        end
    end
end

function eq_derive_variant_field(variant_type)
    body = expr_map(Data.variant_fieldnames(variant_type)) do field
        lhs_value = gensym(:lhs_value)
        rhs_value = gensym(:rhs_value)
        return quote
            $lhs_value = $Base.getproperty(lhs, $(QuoteNode(field)))
            $rhs_value = $Base.getproperty(rhs, $(QuoteNode(field)))
            $lhs_value == $rhs_value || return false
        end # quote
    end

    return quote
        $body
        return true
    end
end
