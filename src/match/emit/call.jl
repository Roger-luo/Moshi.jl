function decons_call(info::PatternInfo, pat::Pattern.Type)
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
    nfields = length(pat.args) + length(pat.kwargs)
    head = Base.eval(info.emit.mod, pat.head)
    if Data.is_data_type(head) # check if our pattern is correct
        Data.variant_nfields(head) >= nfields || throw(SyntaxError("invalid pattern: $pat"))
        Data.variant_kind(head) == Data.Anonymous &&
            length(pat.kwargs) > 0 &&
            throw(SyntaxError("invalid pattern: $pat"))

        type_assert = :($Data.isa_variant($value, $head))
        args_conds = mapfoldl(and_expr, enumerate(pat.args); init=true) do (idx, x)
            call_ex = xcall(Data, :variant_getfield, value, Val(head.tag), idx)
            decons(info, x)(call_ex)
        end
        kwargs_conds = mapfoldl(and_expr, pat.kwargs; init=true) do kw
            key, val = kw
            call_ex = xcall(
                Data, :variant_getfield, value, Val(head.tag), QuoteNode(key)
            )
            decons(info, val)(call_ex)
        end
    elseif isconcretetype(head)
        Base.fieldcount(head) >= nfields ||
            throw(SyntaxError("too many fields to match: $pat"))

        type_assert = :($value isa $head)
        args_conds = mapfoldl(and_expr, enumerate(pat.args); init=true) do (idx, x)
            decons(info, x)(:($Core.getfield($value, $idx)))
        end
        kwargs_conds = mapfoldl(and_expr, pat.kwargs; init=true) do kw
            key, val = kw
            decons(info, val)(:($Core.getfield($value, $key)))
        end
    else
        throw(SyntaxError("invalid pattern: $pat, expect @data type or concrete type"))
    end

    return function call(x)
        return quote
            $value = $x
            $type_assert && $args_conds && $kwargs_conds
        end
    end
end
