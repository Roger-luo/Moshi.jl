# `T[...]` (a `Ref` pattern) normally reads `T` as the *element* type and matches
# `Vector{T}`, mirroring Julia's typed-array literal. When `T` is an *abstract* array
# type (`AbstractVector`, `AbstractArray`, ...), we instead read it as a *container*
# constraint and match any `x isa T` through the array interface — this is what makes
# `AbstractVector[1, x, 3]` match a `view`/`SubArray`/range. Concrete heads (`Int`,
# `Vector`, ...) keep the element-type reading, so existing patterns are unchanged.
Base.@assume_effects :foldable function is_container_head(@nospecialize(T))
    return T isa Type && T <: AbstractArray && isabstracttype(Base.unwrap_unionall(T))
end

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
        # abstract array head => match the container `isa T`; otherwise the head is the
        # element type and we match `Vector{T}` (`is_container_head` folds at compile time)
        return :($is_container_head($(pat.head)) ? $(pat.head) : $Base.Vector{$(pat.head)})
    end
    set_view_type_check!(coll) do view, eltype
        generic = :($Base.eltype($view) <: $eltype # fast path: avoid iterating the view
        || $Base.all($Base.Fix2(isa, $eltype), $view))
        # For the pattern `AP[_, v::VP..., _]` matching a vector `A[_, V[...]..., _]`,
        # the `value isa Vector{AP}` check emitted by `finish_decons` already pins the
        # parent element type to `AP` (Julia's `Vector` is invariant), so the view's
        # `eltype` is statically `AP`. We only need to verify the spliced elements are
        # each a `VP`. This shortcut is unsound for an abstract *container* head, whose
        # `isa T` check does not pin the eltype, so guard it with `is_container_head`.
        if pat.head == eltype
            :($is_container_head($(pat.head)) ? $generic : true)
        else
            generic
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

function decons(::Type{Pattern.Indexable}, ctx::PatternContext, pat::Pattern.Type)
    # `Indexable[...]` matches any `AbstractVector` (a `view`/`SubArray`, range, ...),
    # not just a concrete `Vector`. Otherwise it behaves exactly like the `[...]` pattern.
    coll = CollectionDecons(ctx, pat, pat.xs) do _
        return :($Base.AbstractVector)
    end
    set_view_type_check!(coll) do view, eltype
        return :(
            $Base.eltype($view) <: $eltype || $Base.all($Base.Fix2(isa, $eltype), $view)
        )
    end
    return coll
end
