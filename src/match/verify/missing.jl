"""
Up to `limit` patterns, each matching only values in `space`. If a position in `space`
excludes variants, its examples are the other variants of their `@data` type. If the
excluded variants come from several types, the position has no examples. A position that
excludes only literals shows as `_`, which also covers those literals.
"""
function examples(space::Alt, limit::Int)::Vector{Space}
    found = Space[]
    for member in space.alts
        length(found) < limit || break
        append!(found, examples(member, limit - length(found)))
    end
    return found
end
function examples(space::Ctor, limit::Int)::Vector{Space}
    choices = [examples(field, limit) for field in space.fields]
    combos = Iterators.take(Iterators.product(choices...), limit)
    return Space[Ctor(space.variant, collect(Space, combo)) for combo in combos]
end
examples(space::Lit, limit::Int)::Vector{Space} = Space[space]
function examples(space::Wild, limit::Int)::Vector{Space}
    isempty(space.excluded) && return Space[ANY]
    adts = unique(Type[adt(variant) for variant in space.excluded])
    length(adts) == 1 || return Space[]
    variants = [variant for variant in Data.variants(only(adts)) if admits(space, variant)]
    return Space[
        Ctor(variant, Space[ANY for _ in 1:Data.variant_nfields(variant)]) for
        variant in first(variants, limit)
    ]
end

"""
Up to `limit` patterns no arm surely matches. Empty unless the arms name variants of
exactly one `@data` type. Throws `OutOfSteps` when `budget` runs out.
"""
function missing_patterns(
    cases::Vector{Pattern.Type}, limit::Int, budget::Budget
)::Vector{Space}
    variants = foldl(top_variants!, cases; init=Type[])
    adts = unique(Type[adt(variant) for variant in variants])
    length(adts) == 1 || return Space[]
    unmatched = alt(budget, (full(variant) for variant in Data.variants(only(adts))))
    for case in cases
        unmatched = minus(budget, unmatched, lower(case, EXHAUST, budget))
    end
    return examples(unmatched, limit)
end

"Path of the `@data` module of `variant`, short when `scope` binds that module by name."
function data_path(variant::Type, scope::Module)::String
    data = parentmodule(adt(variant))
    name = nameof(data)
    isdefined(scope, name) && getfield(scope, name) === data && return string(name)
    return join(fullname(data), ".")
end

"`space` as pattern code that compiles in `scope`."
show_space(::Wild, scope::Module)::String = "_"
show_space(space::Lit, scope::Module)::String = repr(space.value)
function show_space(space::Ctor, scope::Module)::String
    name = string(data_path(space.variant, scope), ".", Data.variant_name(space.variant))
    return string(name, "(", join(show_space.(space.fields, Ref(scope)), ", "), ")")
end
