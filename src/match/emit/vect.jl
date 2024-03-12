function decons_ref(info::PatternInfo, pat::Pattern.Type)
    # NOTE: we generate both cases here, because Julia should
    # be able to eliminate one of the branches during compile
    # NOTE: ref syntax <symbol> [<elem>...] has the following cases:
    # 1. <symbol> is defined, and is a type, typed vect
    # 2. <symbol> is not defined in global scope as type,
    #    but is defined as a variable, getindex, the match
    #    will try to find the index that returns the input
    #    value.
    # 2 is not supported for now because I don't see any use case.
    return CollectionDecons(info, pat, pat.args) do _
        :($Base.Vector{$(pat.head)})
    end
end

function decons_untyped_vect(info::PatternInfo, pat::Pattern.Type)
    coll = CollectionDecons(info, pat, pat.xs) do _
        :($Base.Vector)
    end
    set_view_type_check!(coll) do view, eltype
        :(eltype($view) == $eltype)
    end
    return coll
end
