function decons(::Type{Pattern.Ref}, ctx::PatternContext, pat::Pattern.Type)
    # NOTE: we generate both cases here, because Julia should
    # be able to eliminate one of the branches during compile
    # NOTE: ref syntax <symbol> [<elem>...] has the following cases:
    # 1. <symbol> is defined, and is a type, typed vect
    # 2. <symbol> is not defined in global scope as type,
    #    but is defined as a variable, getindex, the match
    #    will try to find the index that returns the input
    #    value.
    # 2 is not supported for now because I don't see any use case.
    coll = CollectionDecons(ctx, pat, pat.args) do _
        return :($Base.Vector{$(pat.head)})
    end
    set_view_type_check!(coll) do view, eltype
        # For the pattern `AP[_, v::VP..., _]` matching a vector `A[_, V[...]..., _]`,
        # the `value isa Vector{AP}` check emitted by `finish_decons` already pins the
        # parent element type to `AP` (Julia's `Vector` is invariant), so the view's
        # `eltype` is statically `AP`. We only need to verify the spliced elements are
        # each a `VP`.
        if pat.head == eltype
            true # view eltype is statically `VP`, nothing left to check
        else
            :($Base.eltype($view) <: $eltype # fast path: avoid iterating the view
            || $Base.all($Base.Fix2(isa, $eltype), $view))
        end
    end
    return coll
end

function decons(::Type{Pattern.Vector}, ctx::PatternContext, pat::Pattern.Type)
    coll = CollectionDecons(ctx, pat, pat.xs) do _
        return :($Base.Vector)
    end
    set_view_type_check!(coll) do view, eltype
        # The view shares the parent's (possibly abstract) `eltype`, so a bare
        # `eltype(view) == VP` never matches a more specific element type. Fall back to
        # checking each element when the static `eltype` is not already a subtype.
        return :(
            $Base.eltype($view) <: $eltype || $Base.all($Base.Fix2(isa, $eltype), $view)
        )
    end
    return coll
end
