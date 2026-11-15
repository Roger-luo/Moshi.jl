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

"Thrown when a check runs out of steps."
struct OutOfSteps <: Exception end

"Steps a check may still take."
mutable struct Budget
    steps::Int
end

"Charge `steps` to `budget`; throw `OutOfSteps` when it runs out."
function spend!(budget::Budget, steps::Int)::Nothing
    budget.steps -= steps
    budget.steps < 0 && throw(OutOfSteps())
    return nothing
end

"""
How `lower` reads what it cannot analyze. `widen` maps unreadable parts (the type in a
type annotation, parametrized variant heads, interpolated values, custom call patterns) to
`ANY`, otherwise to `NO_VALUE`. `tests_pass` treats guards and repeated names as true,
otherwise as matching no value.
"""
struct Mode
    widen::Bool
    tests_pass::Bool
end

"Mode for an arm under test: every value it might accept."
const REACH = Mode(true, true)

"Mode for earlier arms: only values they surely accept."
const COVER = Mode(false, false)

unreadable(mode::Mode)::Space = mode.widen ? ANY : NO_VALUE

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

"""
One arm as `lower!` reads it: the mode, the step budget, and the names bound so far in the
current branch of `||`. A name bound again tests equality.
"""
struct Reading
    mode::Mode
    budget::Budget
    names::Set{Symbol}
end

"Add `name` to the names of `reading`; true when it was there already."
function bind!(reading::Reading, name::Symbol)::Bool
    name in reading.names && return true
    push!(reading.names, name)
    return false
end

"""
`f(branch, side)` for both sides of `||`. Each branch starts from a copy of the names of
`reading`, paid for in steps, and `reading` gains the names either side binds.
"""
function branches!(f, reading::Reading, pat::Pattern.Type)::Tuple
    spend!(reading.budget, length(reading.names))
    left, right = (Reading(reading.mode, reading.budget, copy(reading.names)) for _ in 1:2)
    results = (f(left, pat.:1), f(right, pat.:2))
    union!(reading.names, left.names, right.names)
    return results
end

"Space of values `pat` accepts, read in `mode`."
lower(pat::Pattern.Type, mode::Mode, budget::Budget)::Space =
    lower!(Reading(mode, budget, Set{Symbol}()), pat)

"Space of values `pat` accepts; `reading` gains the names `pat` binds."
lower!(reading::Reading, pat::Pattern.Type)::Space = lower!(reading, variant_type(pat), pat)
lower!(reading::Reading, ::Type, pat::Pattern.Type) = unreadable(reading.mode)
lower!(reading::Reading, ::Type{Pattern.Wildcard}, pat::Pattern.Type) = ANY
function lower!(reading::Reading, ::Type{Pattern.Variable}, pat::Pattern.Type)
    return bind!(reading, pat.:1) && !reading.mode.tests_pass ? NO_VALUE : ANY
end
function lower!(reading::Reading, ::Type{Pattern.Guard}, pat::Pattern.Type)
    return reading.mode.tests_pass ? ANY : NO_VALUE
end
function lower!(reading::Reading, ::Type{Pattern.Or}, pat::Pattern.Type)
    return alt(reading.budget, branches!(lower!, reading, pat))
end
function lower!(reading::Reading, ::Type{Pattern.And}, pat::Pattern.Type)
    left = lower!(reading, pat.:1)
    return both(reading.budget, left, lower!(reading, pat.:2))
end
function lower!(reading::Reading, ::Type{Pattern.TypeAnnotate}, pat::Pattern.Type)
    return both(reading.budget, lower!(reading, pat.body), unreadable(reading.mode))
end
function lower!(reading::Reading, ::Type{Pattern.Call}, pat::Pattern.Type)
    Data.is_variant_type(pat.head) || return unreadable(reading.mode)
    variant = Base.typename(Base.unwrap_unionall(pat.head)).wrapper
    # explicit type parameters (`Opt.Some{Int}`) match only part of the variant
    variant === pat.head || reading.mode.widen || return NO_VALUE
    fieldnames = Data.variant_fieldnames(variant)
    all(in(fieldnames), keys(pat.kwargs)) || return unreadable(reading.mode)
    fields = Space[ANY for _ in 1:Data.variant_nfields(variant)]
    for (idx, arg) in enumerate(pat.args)
        fields[idx] = lower!(reading, arg)
    end
    for (name, arg) in pat.kwargs
        idx = findfirst(==(name), fieldnames)
        fields[idx] = both(reading.budget, fields[idx], lower!(reading, arg))
    end
    return ctor(variant, fields)
end

"""
Indices of unreachable arms: earlier arms match every value they accept. The value may have
any type. Throws `OutOfSteps` when `budget` runs out.
"""
function unreachable_arms(cases::Vector{Pattern.Type}, budget::Budget)::Vector{Int}
    unmatched = ANY
    dead = Int[]
    for (idx, case) in enumerate(cases)
        both(budget, lower(case, REACH, budget), unmatched) == NO_VALUE && push!(dead, idx)
        unmatched = minus(budget, unmatched, lower(case, COVER, budget))
    end
    return dead
end

"Steps one check may take before it stops."
const BUDGET = 100_000

"""
Warn, at macro expansion, about unreachable arms.

The check assumes only declared field types, so a final `_` arm stays reachable. As in
Rust, a guard or a repeated name covers nothing, since its test can fail. Unreadable parts
(the type in a type annotation, parametrized variant heads, interpolated values, custom call
patterns) match every value in the arm under check and no value in earlier arms. Each
warning is therefore certain. Some unreachable arms behind unreadable parts go unreported.
After `budget` steps, the check stops with a warning.
"""
function verify(info, budget::Int=BUDGET)
    any(case -> isa_variant(case, Pattern.Err), info.cases) && return nothing
    try
        for idx in unreachable_arms(info.cases, Budget(budget))
            line = info.lines[idx]
            @warn "unreachable match arm: earlier arms already match every value it accepts" _module =
                info.mod _file = line_file(line) _line = line_number(line)
        end
    catch err
        err isa OutOfSteps || rethrow()
        @warn "match too complex to check: stopped after $budget steps; unreachable arms may go unreported" _module =
            info.mod _file = line_file(info.source) _line = line_number(info.source)
    end
    return nothing
end

line_file(line::LineNumberNode) = line.file === nothing ? nothing : String(line.file)
line_file(::Nothing) = nothing
line_number(line::LineNumberNode) = line.line
line_number(::Nothing) = nothing
