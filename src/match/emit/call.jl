function decons(::Type{Pattern.Call}, ctx::PatternContext, pat::Pattern.Type)
    return decons_call(pat.head, ctx, pat)
end

# NOTE: allow call pattern to be customized
function decons_call(head::Type, ctx::PatternContext, pat::Pattern.Type)
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
    if Data.is_variant_type(head) # check if our pattern is correct
        type_assert = :($Data.isa_variant($value, $head))
        data = gensym(:data)
        storage_type = Data.variant_storage_type(head)
        type_assert = quote
            $data = $Base.getfield($value, :data)
            $data isa $storage_type
        end

        args_conds = mapfoldl(and_expr, enumerate(pat.args); init=true) do (idx, x)
            call_ex = xcall(Base, :getfield, data, idx)
            decons(ctx, x)(call_ex)
        end
        kwargs_conds = mapfoldl(and_expr, pat.kwargs; init=true) do kw
            key, val = kw
            call_ex = xcall(Base, :getfield, data, QuoteNode(key))
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

function decons_call(::Type{Regex}, ctx::PatternContext, pat::Pattern.Type)
    length(pat.args) == 1 || error("expect Regex(<string>) got $pat")
    Data.isa_variant(pat.args[1], Pattern.Quote) || error("Regex head must be a string")
    re = Regex(pat.args[1].:1)
    return function regex(x)
        return quote
            $Base.occursin($re, $x)
        end
    end
end

function decons_call(::Type{LineNumberNode}, ctx::PatternContext, pat::Pattern.Type)
    length(pat.args) == 2 || error(
        "expect LineNumberNode(<line::Int>, <file::Union{Nothing, Symbol, String}>) got $pat",
    )
    return function line_number_node(value)
        return and_expr(
            :($value isa $Base.LineNumberNode),
            decons(ctx, pat.args[1])(:($value.line)),
            decons(ctx, pat.args[2])(:($value.file)),
        )
    end
end
