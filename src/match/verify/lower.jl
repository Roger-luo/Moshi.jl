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
