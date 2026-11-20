"A set of values, as the `@match` checks see it."
abstract type Space end

"Values of type `type`, except values of the `@data` variants in `excluded`."
struct Wild <: Space
    type::Type
    excluded::Vector{Type}
end

"Values of one `@data` variant whose fields lie in `fields`."
struct Ctor <: Space
    variant::Type
    fields::Vector{Space}
end

"Values in any of `alts`; `NO_VALUE` has no alternative."
struct Alt <: Space
    alts::Vector{Space}
end

"Every value."
const ANY = Wild(Any, Type[])

"No value."
const NO_VALUE = Alt(Space[])

Base.:(==)(lhs::Wild, rhs::Wild) = lhs.type === rhs.type && lhs.excluded == rhs.excluded
Base.hash(space::Wild, h::UInt) = hash(space.excluded, hash(space.type, hash(:Wild, h)))
Base.:(==)(lhs::Ctor, rhs::Ctor) = lhs.variant === rhs.variant && lhs.fields == rhs.fields
Base.hash(space::Ctor, h::UInt) = hash(space.fields, hash(space.variant, hash(:Ctor, h)))
Base.:(==)(lhs::Alt, rhs::Alt) = lhs.alts == rhs.alts
Base.hash(space::Alt, h::UInt) = hash(space.alts, hash(:Alt, h))

"The `@data` type of `variant`, without type parameters."
adt(variant::Type)::Type =
    Base.typename(Base.unwrap_unionall(Data.data_type(variant))).wrapper

"True when type `type` holds values of the `@data` type of `variant`."
fits(variant::Type, type::Type)::Bool = typeintersect(type, adt(variant)) !== Union{}

"True when the variants of the one type in `adts` cover every value of type `type`."
complete(adts::Vector{Type}, type::Type)::Bool = length(adts) == 1 && type <: only(adts)

"""
Every value of `variant`, each field at its declared type. Open type parameters read as
`Any`.
"""
full(variant::Type)::Ctor =
    Ctor(variant, Space[Wild(type, Type[]) for type in Data.variant_fieldtypes(variant)])

"`Ctor(variant, fields)`, or `NO_VALUE` when a field holds no value."
ctor(variant::Type, fields::Vector{Space})::Space =
    any(==(NO_VALUE), fields) ? NO_VALUE : Ctor(variant, fields)

"`Wild(type, excluded)`, or `NO_VALUE` when `excluded` holds every value of `type`."
function wild(type::Type, excluded::Vector{Type})::Space
    type === Union{} && return NO_VALUE
    adts = unique(Type[adt(variant) for variant in excluded])
    complete(adts, type) && issubset(Data.variants(only(adts)), excluded) && return NO_VALUE
    return Wild(type, excluded)
end

"""
Union of `spaces`, with nested unions flattened and empty or repeated members dropped.
`ANY` absorbs the other members.
"""
function alt(budget::Budget, spaces)::Space
    members = Space[]
    for space in spaces
        space isa Alt ? append!(members, space.alts) : push!(members, space)
    end
    spend!(budget, length(members))
    ANY in members && return ANY
    unique!(members)
    return length(members) == 1 ? only(members) : Alt(members)
end

"True when `space` may hold a value of `variant`."
admits(space::Wild, variant::Type)::Bool =
    !(variant in space.excluded) && fits(variant, space.type)
