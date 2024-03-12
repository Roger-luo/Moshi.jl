function derive_impl(::Val{:PartialEq}, mod::Module, type::Module)
    jl = JLIfElse()
    for variant_type in variants(type.Type)
        jl[:(vtype == $variant_type)] = eq_derive_variant_field(variant_type)
    end
    jl.otherwise = quote
        return false
    end

    return quote
        Base.@constprop :aggressive function $Base.:(==)(lhs::$type.Type, rhs::$type.Type)
            $Data.variant_tag(lhs) == $Data.variant_tag(rhs) || return false
            vtype = $Data.variant_type(lhs)
            return $(codegen_ast(jl))
        end
    end
end

function eq_derive_variant_field(variant_type)
    fieldtypes = variant_fieldtypes(variant_type)
    fieldnames = variant_fieldnames(variant_type)

    stmts = []
    conds = []
    hash_cache_idx = 0
    for (idx, type) in enumerate(fieldtypes)
        if type <: Hash.Cache
            hash_cache_idx = idx
            continue # skip hash cache
        end

        @gensym lhs rhs
        lhs_val = xcall(Data, :variant_getfield, :lhs, Val(variant_type.tag), idx)
        rhs_val = xcall(Data, :variant_getfield, :rhs, Val(variant_type.tag), idx)
        eq_expr = xcall(Base, :(==), lhs, rhs)
        push!(
            stmts,
            quote
                $lhs = $lhs_val
                $rhs = $rhs_val
            end,
        )
        push!(conds, xcall(Base, :(==), lhs, rhs))
    end
    stmts = Expr(:block, stmts...)
    conds = Expr(:&&, conds...)

    return if hash_cache_idx > 0
        @gensym lhs_hash rhs_hash
        lhs_val = xcall(
            Data, :variant_getfield, :lhs, Val(variant_type.tag), hash_cache_idx
        )
        rhs_val = xcall(
            Data, :variant_getfield, :rhs, Val(variant_type.tag), hash_cache_idx
        )
        quote
            $lhs_hash = $lhs_val
            $rhs_hash = $rhs_val

            if $lhs_hash.is_set && $rhs_hash.is_set
                return $lhs_hash[] == $rhs_hash[]
            else
                $stmts
                return $conds
            end
        end
    else
        return quote
            $stmts
            return $conds
        end
    end
end
