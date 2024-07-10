function decons(::Type{Pattern.Call}, ctx::PatternContext, pat::Pattern.Type)
    # NOTE: when we see a call, it can only be a constructor
    # because our syntactical pattern match is performed on data only
    # args => get field by index, then compare
    # kwargs => get field by name, then compare

    # struct Call
    #     head # must be constant object
    #     args::Vector{Pattern}
    #     kwargs::Dict{Symbol, Pattern}
    # end

    # we need to special case data type because Julia types
    # do not share a common interface with our ADT for getting
    # numbered fields, e.g getproperty(x, ::Int) is not defined for
    # Julia types in general.
    @gensym value
    head = pat.head
    if Data.is_variant_type(head) # check if our pattern is correct
        type_assert = :($Data.isa_variant($value, $head))
        args_conds = mapfoldl(and_expr, enumerate(pat.args); init=true) do (idx, x)
            call_ex = xcall(Data, :variant_getfield, value, head, idx)
            decons(ctx, x)(call_ex)
        end
        kwargs_conds = mapfoldl(and_expr, pat.kwargs; init=true) do kw
            key, val = kw
            call_ex = xcall(
                Data, :variant_getfield, value, head, QuoteNode(key)
            )
            decons(ctx, val)(call_ex)
        end
    else # if isconcretetype(head)
        type_assert = :($value isa $head)
        args_conds = mapfoldl(and_expr, enumerate(pat.args); init=true) do (idx, x)
            decons(ctx, x)(:($Core.getfield($value, $idx)))
        end
        kwargs_conds = mapfoldl(and_expr, pat.kwargs; init=true) do kw
            key, val = kw
            decons(ctx, val)(:($Core.getfield($value, $key)))
        end
    end

    return function call(x)
        return quote
            $value = $x
            $(and_expr(type_assert, args_conds, kwargs_conds))
        end
    end
end
