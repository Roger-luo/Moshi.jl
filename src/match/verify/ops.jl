"""
Values in both spaces. Against a `Wild` side, the fields of the other side narrow to their
declared types. A literal against a different literal or a variant widens to the literal,
since `==` may relate values of different types; `exact` tells when it does not.
"""
both(budget::Budget, left::Alt, right::Space)::Space =
    alt(budget, (both(budget, member, right) for member in left.alts))
both(budget::Budget, left::Union{Wild,Ctor,Lit}, right::Alt)::Space =
    alt(budget, (both(budget, left, member) for member in right.alts))
both(budget::Budget, left::Wild, right::Wild)::Space = wild(
    typeintersect(left.type, right.type),
    union(left.excluded, right.excluded),
    union(left.literals, right.literals),
)
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
both(budget::Budget, left::Lit, right::Wild)::Space =
    right.literals ∋ left ? NO_VALUE : left
both(budget::Budget, left::Wild, right::Lit)::Space = both(budget, right, left)
both(budget::Budget, left::Lit, right::Union{Lit,Ctor})::Space = left
both(budget::Budget, left::Ctor, right::Lit)::Space = right

"True when `both(left, right)` holds only values in both spaces."
function exact(left::Space, right::Space)::Bool
    (left isa Wild || right isa Wild) && return true
    left isa Alt && return all(member -> exact(member, right), left.alts)
    right isa Alt && return all(member -> exact(left, member), right.alts)
    left isa Ctor && right isa Ctor || return left == right
    left.variant === right.variant || return true
    return all(fields -> exact(fields...), zip(left.fields, right.fields))
end

"""
Values of `left` outside `right`. `right` comes from a pattern: each `Wild` in it
excludes nothing, and its type holds every value `left` has at the same position.
"""
minus(budget::Budget, left::Space, right::Wild)::Space = NO_VALUE
minus(budget::Budget, left::Space, right::Alt)::Space =
    foldl((rest, member) -> minus(budget, rest, member), right.alts; init=left)
minus(budget::Budget, left::Alt, right::Union{Ctor,Lit})::Space =
    alt(budget, (minus(budget, member, right) for member in left.alts))
function minus(budget::Budget, left::Wild, right::Ctor)::Space
    admits(left, right.variant) || return left
    others = wild(left.type, Type[left.excluded; right.variant], left.literals)
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
minus(budget::Budget, left::Wild, right::Lit)::Space =
    Wild(left.type, left.excluded, union(left.literals, [right]))
minus(budget::Budget, left::Union{Ctor,Lit}, right::Lit)::Space =
    left == right ? NO_VALUE : left
minus(budget::Budget, left::Lit, right::Ctor)::Space = left
