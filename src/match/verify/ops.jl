"""
Values in both spaces. Against a `Wild` side, the fields of the other side narrow to their
declared types.
"""
both(budget::Budget, left::Alt, right::Space)::Space =
    alt(budget, (both(budget, member, right) for member in left.alts))
both(budget::Budget, left::Union{Wild,Ctor}, right::Alt)::Space =
    alt(budget, (both(budget, left, member) for member in right.alts))
both(budget::Budget, left::Wild, right::Wild)::Space =
    wild(typeintersect(left.type, right.type), union(left.excluded, right.excluded))
both(budget::Budget, left::Ctor, right::Wild)::Space = both(budget, right, left)
function both(budget::Budget, left::Wild, right::Ctor)::Space
    admits(left, right.variant) || return NO_VALUE
    return both(budget, full(right.variant), right)
end
function both(budget::Budget, left::Ctor, right::Ctor)::Space
    left.variant === right.variant || return NO_VALUE
    fields = Space[both(budget, l, r) for (l, r) in zip(left.fields, right.fields)]
    return ctor(left.variant, fields)
end

"""
Values of `left` outside `right`. `right` comes from a pattern: each `Wild` in it
excludes nothing, and its type holds every value `left` has at the same position.
"""
minus(budget::Budget, left::Space, right::Wild)::Space = NO_VALUE
minus(budget::Budget, left::Space, right::Alt)::Space =
    foldl((rest, member) -> minus(budget, rest, member), right.alts; init=left)
minus(budget::Budget, left::Alt, right::Ctor)::Space =
    alt(budget, (minus(budget, member, right) for member in left.alts))
function minus(budget::Budget, left::Wild, right::Ctor)::Space
    admits(left, right.variant) || return left
    others = wild(left.type, Type[left.excluded; right.variant])
    return alt(budget, (others, minus(budget, full(right.variant), right)))
end
function minus(budget::Budget, left::Ctor, right::Ctor)::Space
    left.variant === right.variant || return left
    common = Space[both(budget, l, r) for (l, r) in zip(left.fields, right.fields)]
    any(==(NO_VALUE), common) && return left
    # split the values outside `right` by the first field that falls outside it
    terms = map(eachindex(common)) do idx
        rest = minus(budget, left.fields[idx], right.fields[idx])
        return ctor(
            left.variant, Space[common[1:(idx - 1)]; rest; left.fields[(idx + 1):end]]
        )
    end
    return alt(budget, terms)
end
