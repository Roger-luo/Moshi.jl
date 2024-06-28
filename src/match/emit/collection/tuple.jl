function decons(::Type{Pattern.Tuple}, ctx::PatternContext, pat::Pattern.Type)
    coll = CollectionDecons(ctx, pat, pat.xs) do splat_idx
        if splat_idx == 0 # no splat, guess full type
            tuple_pattern_type(pat)
        else
            :($Base.Tuple)
        end
    end
    set_view_type_check!(coll) do view, eltype
        @gensym N
        :($view isa $Base.NTuple{$N,$eltype} where {$N})
    end
    return coll
end

function tuple_pattern_type(pat::Pattern.Type)
    type_params = map(pat.xs) do x
        if isa_variant(x, Pattern.Quote)
            :($Base.typeof($(x.:1)))
        else
            Any
        end
    end
    return :($Base.Tuple{$(type_params...)})
end
