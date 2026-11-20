using Test
using Random: Xoshiro
using Moshi.Data: @data
using Moshi.Match: @match, Pattern, EmitInfo
import Moshi.Match

@data Shape begin
    Empty()
    Circle(Float64)
    struct Rect
        w::Float64
        h::Float64
    end
end

@data Opt{T} begin
    None()
    Some(T)
end

@data Bit begin
    Zero()
    One()
end

@data Grid begin
    Blank()
    Mono(Bit.Type)
    Duo(Bit.Type, Bit.Type)
end

@data Holder begin
    Hold(Any)
end

@data Loose begin
    Typed(Bit.Type)
    Untyped(Any)
end

@data Nest begin
    In(Loose.Type)
end

@eval @data Wide begin
    W($(fill(:(Bit.Type), 20)...))
end

const EMPTY = Shape.Empty()
const ZERO = Bit.Zero()

"""
`Grid.Mono(Bit.Zero() || _)` joined by `&&` 18 times. Distributing `&&` over `||` gives
2^18 alternatives.
"""
const CHAIN = foldl(
    (lhs, rhs) -> Expr(:&&, lhs, rhs), fill(:(Grid.Mono(Bit.Zero() || _)), 18)
)

"Expand `ex` at run time, inside `@test_logs`."
expand(ex) = Core.eval(@__MODULE__, :(() -> $ex))

"Arms of `@match v body`."
arms_of(body::Expr)::Vector{Pattern.Type} = EmitInfo(@__MODULE__, :v, body).cases

"A fresh budget of `Match.BUDGET` steps."
budget() = Match.Budget(Match.BUDGET)

"Steps `run(budget)` spends."
function spent(run)::Int
    steps = budget()
    run(steps)
    return Match.BUDGET - steps.steps
end

@testset "log group" begin
    logs, _ = Test.collect_test_logs() do
        expand(:(@match Shape.Empty() begin
            _ => 0
            Shape.Empty() => 1
        end))
    end
    @test only(logs).group === :unreachable_match_arm
end

@testset "unreachable arm" begin
    @test_logs (:warn, r"unreachable match arm") expand(:(@match Shape.Empty() begin
        _ => 0
        Shape.Empty() => 1
    end))
    @test_logs (:warn, r"unreachable match arm") expand(
        :(@match Shape.Empty() begin
            Shape.Circle(_) => 1
            Shape.Empty() || Shape.Rect(_, _) => 2
            Shape.Rect(_, _) || Shape.Circle(_) => 3
        end)
    )
    @test_logs (:warn, r"unreachable match arm") expand(:(@match Grid.Blank() begin
        Grid.Mono(Bit.Zero()) => 0
        Grid.Mono(Bit.One()) => 1
        Grid.Mono(_) => 2
        _ => 3
    end))
    @test_logs (:warn, r"unreachable match arm") expand(
        :(@match Shape.Empty() begin
            Shape.Circle(_) && Shape.Empty() => 0
            _ => 1
        end)
    )
    # a variant that cannot fit its field's declared type matches nothing
    @test_logs (:warn, r"unreachable match arm") expand(
        :(@match Shape.Empty() begin
            Shape.Circle(Bit.Zero()) => 0
            _ => 1
        end)
    )
    # `Bit` variants cover a `Bit.Type` field, so `Grid.Mono(_)` is unreachable
    @test_logs (:warn, r"unreachable match arm") (:warn, r"unreachable match arm") expand(
        :(@match Grid.Blank() begin
            Grid.Mono(Shape.Empty()) => 0
            Grid.Mono(Bit.Zero()) => 1
            Grid.Mono(Bit.One()) => 2
            Grid.Mono(_) => 3
            _ => 4
        end)
    )
    # `_` gives the fields of each variant their declared types
    @test_logs (:warn, r"unreachable match arm") expand(
        :(@match Nest.In(Loose.Untyped(1)) begin
            Nest.In(Loose.Typed(Bit.Zero())) => 0
            Nest.In(Loose.Typed(Bit.One())) => 1
            Nest.In(Loose.Untyped(_)) => 2
            Nest.In(_) => 3
        end)
    )
    @test_logs (:warn, r"unreachable match arm") expand(
        :(@match Shape.Empty() begin
            Shape.Circle(r) || Shape.Circle(r) => 1
            Shape.Circle(_) && if 1 == 1
            end => 2
            _ => 3
        end)
    )
    # each side of `||` binds its names afresh
    @test_logs (:warn, r"unreachable match arm") expand(
        :(@match Grid.Blank() begin
            Grid.Duo(a, Bit.Zero()) || Grid.Duo(a, Bit.One()) => 0
            Grid.Duo(_, _) => 1
            _ => 2
        end)
    )
    # an arm that differs from an earlier arm in every field stays reachable
    @test_logs expand(:(@match Grid.Blank() begin
        Grid.Duo(Bit.Zero(), Bit.Zero()) => 0
        Grid.Duo(Bit.One(), Bit.One()) => 1
        _ => 2
    end))
    # the check reads the pattern of a type annotation
    @test_logs (:warn, r"unreachable match arm") expand(:(@match Grid.Blank() begin
        Grid.Mono(_) => 0
        Grid.Mono(_)::Grid.Type => 1
        _ => 2
    end))
    # a name on both sides of a nested `||` is bound once
    @test_logs (:warn, r"unreachable match arm") expand(:(@match Grid.Blank() begin
        Grid.Mono(a || a) => 0
        Grid.Mono(_) => 1
        _ => 2
    end))
    # `Bit.Zero() || _` reads as `_`, so the chain lowers to one variant
    case = only(arms_of(Expr(:block, :($CHAIN => 1))))
    @test Match.lower(case, Match.REACH, budget()) == Match.Ctor(Grid.Mono, [Match.ANY])
    @test_logs (:warn, r"unreachable match arm") expand(:(@match Grid.Blank() begin
        $CHAIN => 1
        Grid.Mono(_) => 2
        _ => 3
    end))

    @testset "reachable" begin
        @test_logs expand(:(@match Shape.Empty() begin
            Shape.Circle(r) && if r > 0
            end => 1
            Shape.Circle(_) => 2
            _ => 3
        end))
        @test_logs expand(:(@match Shape.Empty() begin
            Shape.Circle(_) => 1
            Shape.Circle(_) || Shape.Empty() => 2
            _ => 3
        end))
        @test_logs expand(:(@match Shape.Empty() begin
            _::Shape.Type => 1
            Shape.Circle(_) => 2
        end))
        @test_logs expand(:(@match Shape.Empty() begin
            $(Expr(:$, :EMPTY)) => 0
            Shape.Empty() => 1
            _ => 2
        end))
        @test_logs expand(:(@match Opt.Some("a") begin
            Opt.Some{Int}(v) => 1
            Opt.Some{String}(v) => 2
            _ => 3
        end))
        @test_logs expand(:(@match Grid.Blank() begin
            Grid.Duo(a, _) && a => 1
            Grid.Duo(_, _) => 2
            _ => 3
        end))
        @test_logs expand(:(@match Shape.Empty() begin
            Shape.Circle(_) => 1
            Shape.Circle(_) || if 1 == 1
            end => 2
            _ => 3
        end))
        # names bound inside `||` count for the rest of the pattern
        @test_logs expand(:(@match Grid.Blank() begin
            Grid.Duo(a || a, a) => 0
            Grid.Duo(_, _) => 1
            _ => 2
        end))
        # a keyword that names no field makes the pattern unreadable
        @test_logs expand(:(@match Shape.Empty() begin
            Shape.Rect(; z) => 0
            Shape.Rect(_, _) => 1
            _ => 2
        end))
        # a repeated name in one `||` branch narrows only that branch
        @test_logs expand(:(@match Grid.Blank() begin
            Grid.Duo(a, a) || Grid.Mono(a && a) => 0
            Grid.Duo(Bit.Zero(), Bit.One()) => 1
            _ => 2
        end))
    end

    @testset "fallback arms catch values of other types" begin
        @test_logs expand(:(@match Bit.Zero() begin
            Bit.Zero() => 0
            Bit.One() => 1
            _ => 2
        end))
        @test_logs expand(:(@match Holder.Hold(1) begin
            Holder.Hold(Bit.Zero()) => 0
            Holder.Hold(Bit.One()) => 1
            Holder.Hold(_) => 2
        end))
        @test_logs expand(:(@match Opt.Some(1) begin
            Opt.Some(Bit.Zero()) || Opt.Some(Bit.One()) => 0
            Opt.Some(_) => 1
            _ => 2
        end))
        # `Untyped` holds `Any`, so `Untyped(1)` reaches the last arm
        @test_logs expand(:(@match Loose.Untyped(1) begin
            Loose.Typed(Bit.Zero()) || Loose.Untyped(Bit.Zero()) => 0
            Loose.Typed(Bit.One()) || Loose.Untyped(Bit.One()) => 1
            Loose.Typed(_) || Loose.Untyped(_) => 2
        end))
    end
end

@testset "literal patterns" begin
    @testset "unreachable" begin
        @test_logs (:warn, r"unreachable match arm") expand(:(@match 1 begin
            1 => 0
            1 => 1
            _ => 2
        end))
        @test_logs (:warn, r"unreachable match arm") expand(:(@match "a" begin
            "a" || :b || 'c' => 0
            :b => 1
            _ => 2
        end))
        @test_logs (:warn, r"unreachable match arm") expand(:(@match Shape.Empty() begin
            Shape.Rect(1.0, _) => 0
            Shape.Rect(1.0, 2.0) => 1
            _ => 2
        end))
        @test_logs (:warn, r"unreachable match arm") expand(:(@match Shape.Empty() begin
            Shape.Rect(1.0, 2.0) => 0
            Shape.Rect(_, 3.0) => 1
            Shape.Rect(1.0, 2.0) => 2
            _ => 3
        end))
        # `1 && 1.0` accepts only values `==` to 1, which the first arm took
        @test_logs (:warn, r"unreachable match arm") expand(:(@match 1 begin
            1 => 0
            1 && 1.0 => 1
            _ => 2
        end))
    end

    @testset "reachable" begin
        @test_logs expand(:(@match 1 begin
            1 => 0
            2 => 1
            _ => 2
        end))
        # `==` relates literals of different types, so only the same literal repeats
        @test_logs expand(:(@match 1 begin
            1 => 0
            1.0 => 1
            _ => 2
        end))
        # an earlier `&&` of different literals covers nothing
        @test_logs expand(:(@match 1 begin
            1 && 1.0 => 0
            1 => 1
            _ => 2
        end))
        @test_logs expand(:(@match Shape.Empty() begin
            Shape.Rect(1.0; w=2.0) => 0
            Shape.Rect(1.0, _) => 1
            _ => 2
        end))
        @test_logs expand(:(@match Shape.Empty() begin
            Shape.Rect(1.0, 2.0) => 0
            Shape.Rect(1.0, _) => 1
            Shape.Rect(_, 2.0) => 2
            _ => 3
        end))
    end
end

@testset "edge cases" begin
    # a keyword field narrows the positional pattern on the same field
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Rect(1.0; w) => w
        Shape.Rect(_, _) => 0
        _ => 1
    end))
    # `&&` of one variant keeps the fields of both sides
    @test_logs expand(:(@match Grid.Blank() begin
        Grid.Mono(_) && Grid.Mono(Bit.Zero()) => 0
        Grid.Mono(Bit.One()) => 1
        _ => 2
    end))
    # a guard inside a field also makes the arm cover nothing
    @test_logs expand(:(@match Grid.Blank() begin
        Grid.Mono(b && if b == ZERO
        end) => 0
        Grid.Mono(_) => 1
        _ => 2
    end))
end

@testset "space operations" begin
    # the wildcard of a pattern keeps the variants a leftover set excludes
    without_zero = Match.Wild(Bit.Type, Type[Bit.Zero])
    @test Match.both(budget(), Match.ANY, without_zero) == without_zero
    @test Match.both(budget(), without_zero, Match.ANY) == without_zero
    # a leftover set excludes the literals earlier arms took
    one = Match.Lit(1)
    without_one = Match.minus(budget(), Match.ANY, one)
    @test without_one == Match.Wild(Any, Type[], [one])
    @test Match.both(budget(), one, without_one) == Match.NO_VALUE
    @test Match.both(budget(), Match.Lit(1.0), without_one) == Match.Lit(1.0)
    @test !Match.exact(one, Match.Lit(1.0))
    # disjoint types share no value
    @test Match.both(
        budget(), Match.Wild(Bit.Type, Type[]), Match.Wild(Grid.Type, Type[])
    ) == Match.NO_VALUE
end

"`n` copies of `atom` joined by `&&`."
chain(atom, n::Int) = foldl((lhs, rhs) -> Expr(:&&, lhs, rhs), fill(atom, n))

@testset "steps stay bounded" begin
    # independent `||` fields stay one variant with `||` fields
    either = :(Bit.Zero() || Bit.One())
    cases = arms_of(:(
        begin
            Wide.W($(fill(either, 20)...)) => 1
            Wide.W($(fill(:_, 20)...)) => 2
        end
    ))
    @test spent(steps -> @test Match.unreachable_arms(cases, steps) == [2]) < 1_000
    # identical `||` branches collapse
    dup = only(arms_of(:(
        begin
            Bit.Zero() || Bit.Zero() => 1
        end
    )))
    @test Match.lower(dup, Match.COVER, budget()) == Match.Ctor(Bit.Zero, Match.Space[])
    # the check spends steps linear in the length of an `&&` chain
    atoms = (:(Grid.Mono(Bit.Zero() || _)), :(Grid.Duo(Bit.Zero() || Bit.One(), _)), :x)
    @testset "$atom" for atom in atoms
        cost(n) = spent() do steps
            cases = arms_of(Expr(:block, :($(chain(atom, n)) => 1), :(Grid.Blank() => 2)))
            Match.unreachable_arms(cases, steps)
        end
        @test cost(64) <= 3 * cost(32)
    end
    named = [Expr(:||, Symbol(:x, i), Symbol(:x, i)) for i in 1:64]
    copies(n) = spent() do steps
        pattern = foldl((lhs, rhs) -> Expr(:&&, lhs, rhs), named[1:n])
        Match.unreachable_arms(arms_of(Expr(:block, :($pattern => 1))), steps)
    end
    # each `||` pays for copying the names bound before it
    @test copies(64) >= 3 * copies(32)
    # a check past its budget throws, and `@match` then warns
    gap = arms_of(:(
        begin
            Grid.Blank() => 0
            Grid.Mono(_) => 1
        end
    ))
    @test isempty(Match.unreachable_arms(gap, budget()))
    @test_throws Match.OutOfSteps Match.unreachable_arms(gap, Match.Budget(1))
    info = EmitInfo(@__MODULE__, :v, :(
        begin
            Grid.Blank() => 0
            Grid.Mono(_) => 1
        end
    ))
    @test_logs (:warn, r"match too complex to check: stopped after 1 steps") Match.verify(
        info, 1
    )
end

@testset "match still behaves" begin
    @test 1 == @match Shape.Circle(1.0) begin
        Shape.Empty() => 0
        Shape.Circle(r) => 1
        Shape.Rect(w, h) => 2
    end
end

const BITS = [Bit.Zero(), Bit.One()]
const UNIVERSE = [
    Grid.Blank();
    [Grid.Mono(b) for b in BITS];
    [Grid.Duo(x, y) for x in BITS for y in BITS]
]

"Every `Grid` value, then one value of another type."
const VALUES = [UNIVERSE; :other]

"""
Random field pattern. `name` is the variable it may bind, `:_` for none; `:guarded` mode
may also reuse `a`, and `:blind` mode adds patterns the checks cannot read.
"""
function bit_pattern(rng, mode::Symbol, name::Symbol)
    choices = Any[:_, :(Bit.Zero()), :(Bit.One()), :(Bit.Zero() || Bit.One()), name]
    mode === :blind && append!(choices, [:(_::Bit.Type), Expr(:$, :ZERO)])
    mode === :guarded && name !== :_ && push!(choices, :a)
    return rand(rng, choices)
end

"`pat && if cond end`, with `cond` true or false at random."
function with_guard(rng, pat)
    return Expr(:&&, pat, Expr(:if, :($(rand(rng, 1:2)) == 1), Expr(:block)))
end

"""
Random arm pattern over `Grid`, nesting `||` and `&&` up to `depth` levels. Branches bind
the same names, each once. Otherwise Moshi throws `UndefVarError` when the other branch
matches.
"""
function grid_pattern(rng, mode::Symbol, depth::Int=2, binds::Bool=true)
    a, b = binds ? (:a, :b) : (:_, :_)
    choice = rand(rng, 1:9)
    choice == 1 && return :_
    choice == 2 && return :(Grid.Blank())
    choice == 3 && return :(Grid.Mono($(bit_pattern(rng, mode, a))))
    choice in (4, 5) &&
        return :(Grid.Duo($(bit_pattern(rng, mode, a)), $(bit_pattern(rng, mode, b))))
    if choice == 6 && depth > 0
        lhs, rhs = (grid_pattern(rng, mode, depth - 1, false) for _ in 1:2)
        return Expr(:||, lhs, rhs)
    end
    if choice == 7 && mode === :guarded
        return Expr(:(::), grid_pattern(rng, mode, depth - 1, binds), :(Grid.Type))
    end
    if choice == 8 && mode === :guarded && binds
        second = rand(rng, Any[:_, :(Bit.Zero())])
        return :(Grid.Duo(a, $second) || Grid.Mono(a))
    end
    if choice == 9 && depth > 0
        lhs, rhs = (grid_pattern(rng, mode, depth - 1, false) for _ in 1:2)
        return Expr(:&&, lhs, rhs)
    end
    mode === :guarded && return with_guard(rng, grid_pattern(rng, mode, depth - 1, binds))
    mode === :blind && return :(_::Grid.Type)
    return :(Grid.Duo(_, _))
end

"Compile `v -> @match v body` without showing its warnings."
function compile(body::Expr)
    return last(
        Test.collect_test_logs(() -> Core.eval(@__MODULE__, :(v -> @match v $body)))
    )
end

"Arm index each of `VALUES` reaches, 0 when the match falls through."
function outcomes(body::Expr)::Vector{Int}
    fn = compile(body)
    return map(VALUES) do value
        try
            Base.invokelatest(fn, value)
        catch err
            err isa ErrorException && err.msg == "matching non-exhaustive" || rethrow()
            0
        end
    end
end

@testset "property: checks agree with compiled matches" begin
    rng = Xoshiro(20261114)
    for trial in 1:240
        mode = (:readable, :guarded, :blind)[mod1(trial, 3)]
        arms = [:($(grid_pattern(rng, mode)) => $idx) for idx in 1:rand(rng, 1:4)]
        body = Expr(:block, arms...)
        cases = EmitInfo(@__MODULE__, :v, body).cases
        reached = outcomes(body)
        dead = Match.unreachable_arms(cases, budget())
        # each reported arm is dead; with readable arms, each dead arm is reported
        @test all(idx -> !(idx in reached), dead)
        mode === :readable &&
            @test all(idx -> idx in dead || idx in reached, eachindex(arms))
    end
end
