include("budget.jl")
include("space.jl")
include("ops.jl")
include("lower.jl")

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
