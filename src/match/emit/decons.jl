function decons(info::PatternInfo, pat::Pattern.Type)
    return function value_assigned(x)
        @gensym value
        return quote
            $value = $x
            $(inner_decons(info, pat)(value))
        end
    end
end

function inner_decons(info::PatternInfo, pat::Pattern.Type)
    isa_variant(pat, Pattern.Wildcard) && return decons_wildcard(info, pat)
    isa_variant(pat, Pattern.Variable) && return decons_variable(info, pat)
    isa_variant(pat, Pattern.Guard) && return decons_guard(info, pat)
    isa_variant(pat, Pattern.Quote) && return decons_quote(info, pat)
    isa_variant(pat, Pattern.And) && return decons_and(info, pat)
    isa_variant(pat, Pattern.Or) && return decons_or(info, pat)
    isa_variant(pat, Pattern.Ref) && return decons_ref(info, pat)
    isa_variant(pat, Pattern.Call) && return decons_call(info, pat)
    isa_variant(pat, Pattern.Tuple) && return decons_tuple(info, pat)
    isa_variant(pat, Pattern.Vector) && return decons_untyped_vect(info, pat)
    isa_variant(pat, Pattern.Splat) && return decons_splat(always_true, info, pat)
    isa_variant(pat, Pattern.TypeAnnotate) && return decons_type_annotate(info, pat)

    return error("invalid pattern: $pat")
end
