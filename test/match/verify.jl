using Test
using Random: Xoshiro
using Moshi.Data: @data
using Moshi.Match: @match, PatternContext, Pattern, EmitInfo
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

@data Five begin
    V1()
    V2()
    V3()
    V4()
    V5()
end

@data Tagged begin
    Flag(Bit.Type)
    Count(Int)
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

"Call pattern that matches every value."
struct Anything end
Match.decons_call(::Type{Anything}, ::PatternContext, ::Pattern.Type) = _ -> true

struct Box
    x::Int
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
        @test_logs (:warn, r"unreachable match arm") expand(
            :(@match Shape.Empty() begin
                Shape.Rect(1.0, _) => 0
                Shape.Rect(1.0, 2.0) => 1
                _ => 2
            end)
        )
        @test_logs (:warn, r"unreachable match arm") expand(
            :(@match Shape.Empty() begin
                Shape.Rect(1.0, 2.0) => 0
                Shape.Rect(_, 3.0) => 1
                Shape.Rect(1.0, 2.0) => 2
                _ => 3
            end)
        )
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
    @test spent(steps -> @test isempty(Match.missing_patterns(cases[1:1], 3, steps))) <
        1_000
    # identical `||` branches collapse
    dup = only(arms_of(:(
        begin
            Bit.Zero() || Bit.Zero() => 1
        end
    )))
    @test Match.lower(dup, Match.COVER, budget()) == Match.Ctor(Bit.Zero, Match.Space[])
    # both checks spend steps linear in the length of an `&&` chain
    atoms = (:(Grid.Mono(Bit.Zero() || _)), :(Grid.Duo(Bit.Zero() || Bit.One(), _)), :x)
    @testset "$atom" for atom in atoms
        cost(n) = spent() do steps
            cases = arms_of(Expr(:block, :($(chain(atom, n)) => 1), :(Grid.Blank() => 2)))
            Match.unreachable_arms(cases, steps)
            Match.missing_patterns(cases, 3, steps)
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
    @test length(Match.missing_patterns(gap, 3, budget())) == 1
    @test_throws Match.OutOfSteps Match.missing_patterns(gap, 3, Match.Budget(1))
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

@testset "non-exhaustive" begin
    logs, _ = Test.collect_test_logs() do
        expand(:(@match Shape.Empty() begin
            Shape.Circle(r) => r
        end))
    end
    @test only(logs).group === :non_exhaustive_match
    # a literal field leaves the literal in the hint of the other field
    @test_logs (:warn, r"no arm matches `Shape\.Rect\(_, _\)`, `Shape\.Rect\(1\.0, _\)`;") expand(
        :(@match Shape.Empty() begin
            Shape.Empty() => 0
            Shape.Circle(_) => 1
            Shape.Rect(1.0, 2.0) => 2
        end)
    )
    @test_logs (:warn, r"no arm matches `Shape\.Rect\(_, _\)`;") expand(
        :(@match Shape.Empty() begin
            Shape.Empty() => 0
            Shape.Circle(r) => r
        end)
    )
    @test_logs (:warn, r"no arm matches `Shape\.Empty\(\)`, `Shape\.Rect\(_, _\)`;") expand(
        :(@match Shape.Empty() begin
            Shape.Circle(r) => r
        end)
    )
    @test_logs (:warn, r"no arm matches `Grid\.Mono\(Bit\.One\(\)\)`;") expand(
        :(@match Grid.Blank() begin
            Grid.Blank() => 0
            Grid.Mono(Bit.Zero()) => 1
            Grid.Duo(_, _) => 2
        end)
    )
    @test_logs (:warn, r"`Grid\.Duo\(Bit\.Zero\(\), Bit\.One\(\)\)`") expand(
        :(@match Grid.Blank() begin
            Grid.Duo(Bit.One(), _) => 0
            Grid.Duo(_, Bit.Zero()) => 1
            Grid.Blank() || Grid.Mono(_) => 2
        end)
    )
    @test_logs (:warn, r"`Five\.V2\(\)`, `Five\.V3\(\)`, `Five\.V4\(\)` and more;") expand(
        :(@match Five.V1() begin
            Five.V1() => 1
        end)
    )
    @test_logs (:warn, r"`Opt\.None\(\)`") expand(:(@match Opt.Some(1) begin
        Opt.Some{Int}(x) => x
    end))
    # variants named on one side of `&&` or `||`, or under a type annotation, name the type
    @test_logs (:warn, r"no arm matches `Shape\.Empty\(\)`, `Shape\.Rect\(_, _\)`;") expand(
        :(@match Shape.Empty() begin
            x && Shape.Circle(_) => x
        end)
    )
    @test_logs (:warn, r"no arm matches `Shape\.Empty\(\)`, `Shape\.Rect\(_, _\)`;") expand(
        :(@match Shape.Empty() begin
            (
                if 1 == 0
                end
            ) || Shape.Circle(_) => 0
        end)
    )
    @test_logs (:warn, r"no arm matches `Shape\.Empty\(\)`, `Shape\.Rect\(_, _\)`;") expand(
        :(@match Shape.Empty() begin
            Shape.Circle(r)::Shape.Type => r
        end)
    )
    # hints do not overlap
    @test_logs (
        :warn,
        r"no arm matches `Grid\.Duo\(Bit\.One\(\), _\)`, `Grid\.Duo\(Bit\.Zero\(\), Bit\.One\(\)\)`;",
    ) expand(:(@match Grid.Blank() begin
        Grid.Duo(Bit.Zero(), Bit.Zero()) => 0
        Grid.Blank() || Grid.Mono(_) => 1
    end))
    # an arm outside a gap leaves the gap's hint whole
    @test_logs (:warn, r"unreachable match arm") (
        :warn, r"no arm matches `Grid\.Duo\(_, Bit\.Zero\(\)\)`;"
    ) expand(:(@match Grid.Blank() begin
        Grid.Duo(_, Bit.One()) => 0
        Grid.Duo(Bit.Zero(), Bit.One()) => 1
        Grid.Blank() || Grid.Mono(_) => 2
    end))
    # a hint names only variants that fit the field's declared type
    @test_logs (:warn, r"unreachable match arm") (
        :warn, r"no arm matches `Shape\.Circle\(_\)`;"
    ) expand(:(@match Shape.Empty() begin
        Shape.Circle(Bit.Zero()) => 0
        Shape.Empty() => 1
        Shape.Rect(_, _) => 2
    end))
    @test_logs (:warn, r"no arm matches `Grid\.Blank\(\)`, `Grid\.Duo\(_, _\)`;") expand(
        :(@match Grid.Blank() begin
            $CHAIN => 1
        end)
    )
    # `Count` holds `Int`, so `Bit` patterns leave `Count(_)` unmatched
    @test_logs (:warn, r"no arm matches `Tagged\.Count\(_\)`;") expand(
        :(@match Tagged.Count(1) begin
            Tagged.Flag(Bit.Zero()) || Tagged.Count(Bit.Zero()) => 0
            Tagged.Flag(Bit.One()) || Tagged.Count(Bit.One()) => 1
        end)
    )
    # an arm matching no value still names the `@data` type
    @test_logs (:warn, r"unreachable match arm") (
        :warn, r"no arm matches `Bit\.Zero\(\)`, `Bit\.One\(\)`;"
    ) expand(:(@match Bit.Zero() begin
        Bit.Zero() && Bit.One() => 0
    end))

    @testset "guarded arm covers nothing" begin
        @test_logs (:warn, r"no arm matches `Shape\.Circle\(_\)`;") expand(
            :(@match Shape.Empty() begin
                Shape.Circle(r) && if r > 0
                end => r
                Shape.Empty() => 0
                Shape.Rect(_, _) => 1
            end)
        )
        @test_logs (:warn, r"no arm matches `Grid\.Duo\(_, _\)`;") expand(
            :(@match Grid.Blank() begin
                Grid.Duo(a, a) => 0
                Grid.Blank() || Grid.Mono(_) => 1
            end)
        )
        @test_logs (
            :warn, r"`Shape\.Empty\(\)`, `Shape\.Circle\(_\)`, `Shape\.Rect\(_, _\)`"
        ) expand(:(@match Shape.Empty() begin
            Shape.Circle(r) && if r > 0
            end => r
        end))
        # also inside a type annotation
        @test_logs (:warn, r"no arm matches `Grid\.Mono\(_\)`;") expand(
            :(@match Grid.Blank() begin
                (Grid.Mono(_) && if 1 == 0
                end)::Grid.Type => 0
                Grid.Blank() => 1
                Grid.Duo(_, _) => 2
            end)
        )
    end

    @testset "warns once, at the match line" begin
        line = (@__LINE__) + 2
        logs, _ = Test.collect_test_logs() do
            expand(:(@match Shape.Empty() begin
                Shape.Empty() => 0
            end))
        end
        @test length(logs) == 1
        @test logs[1].file == string(@__FILE__)
        @test logs[1].line == line
    end
end

@testset "exhaustive: no warning" begin
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Empty() => 0
        Shape.Circle(r) => r
        Shape.Rect(; w) => w
    end))
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Circle(r) => r
        _ => 0
    end))
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Circle(r) => r
        Shape.Empty() || Shape.Rect(_, _) => 0
    end))
    @test_logs expand(:(@match Grid.Blank() begin
        Grid.Duo(Bit.One(), _) => 0
        Grid.Duo(_, Bit.Zero()) => 1
        Grid.Duo(Bit.Zero(), Bit.One()) => 2
        Grid.Blank() || Grid.Mono(_) => 3
    end))
    @test_logs expand(:(@match Grid.Blank() begin
        Grid.Mono(b) && if b == ZERO
        end => 0
        Grid.Mono(_) => 1
        _ => 2
    end))
end

@testset "unreadable patterns hide gaps" begin
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Circle(r) => r
        _::Shape.Type => 0
    end))
    @test_logs expand(:(@match Shape.Empty() begin
        $(Expr(:$, :EMPTY)) => 0
        Shape.Circle(_) => 1
    end))
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Circle(r) => r
        Anything() => 0
    end))
    @test_logs expand(:(@match Shape.Empty() begin
        Box(1) => 0
        Shape.Circle(_) => 1
    end))
    # arms name two `@data` types, so the value type is unknown
    @test_logs expand(:(@match Shape.Empty() begin
        Shape.Circle(r) => r
        Opt.None() => 0
    end))
    # a guarded arm still names its `@data` type, so the value type stays unknown
    @test_logs expand(:(@match Shape.Empty() begin
        Opt.None() && if 1 == 1
        end => 0
        Shape.Circle(r) => r
    end))
    # a field holding two `@data` types has no known signature
    @test_logs expand(:(@match Holder.Hold(1) begin
        Holder.Hold(Bit.Zero()) => 0
        Holder.Hold(Opt.None()) => 1
    end))
    # no variant at all: plain Julia values
    @test_logs expand(:(@match 1 begin
        1 => 0
        x && if x > 1
        end => 1
    end))
end

@testset "tests inside unreadable patterns" begin
    # a guard nested in a tuple pattern still covers nothing
    @test_logs (:warn, r"no arm matches `Holder\.Hold\(_\)`;") expand(
        :(@match Holder.Hold((1, 2)) begin
            Holder.Hold((a && if a > 0
            end, b)) => 0
        end)
    )
    # so does a guard on one side of `||` in a tuple pattern
    @test_logs (:warn, r"no arm matches `Holder\.Hold\(_\)`;") expand(
        :(@match Holder.Hold((1, 2)) begin
            Holder.Hold((Bit.Zero() || if 1 == 0
            end, b)) => 0
        end)
    )
    # so does a name bound twice in a tuple pattern
    @test_logs (:warn, r"no arm matches `Holder\.Hold\(_\)`;") expand(
        :(@match Holder.Hold((1, 2)) begin
            Holder.Hold((a, a)) => 0
        end)
    )
    # a repeat inside the tuple makes only its side of `||` cover nothing
    @test_logs (:warn, r"no arm matches `Holder\.Hold\(Bit\.One\(\)\)`;") expand(
        :(@match Holder.Hold((1, 2)) begin
            Holder.Hold((a, a) || (Bit.Zero() && a)) => 0
        end)
    )
end

@testset "examples respect the limit" begin
    others = Match.Wild(Any, Type[Five.V1])
    @test length(Match.examples(others, 2)) == 2
    @test length(Match.examples(Match.Ctor(Grid.Duo, Match.Space[others, others]), 3)) == 3
    wilds = Match.Alt(Match.Space[Match.Wild(Int, Type[]), Match.Wild(String, Type[])])
    @test length(Match.examples(wilds, 1)) == 1
end

module Elsewhere
using Moshi.Data: @data
@data Far begin
    Near()
    Away()
end
end

module Aliased
using Moshi.Match: @match
const F = parentmodule(@__MODULE__).Elsewhere.Far
end

@testset "missing patterns compile where the match is" begin
    logs, _ = Test.collect_test_logs() do
        Core.eval(Aliased, :(v -> @match v begin
            F.Near() => 0
        end))
    end
    hint = match(r"no arm matches `([^`]+)`", only(logs).message)[1]
    @test endswith(hint, "Elsewhere.Far.Away()")
    fn = Core.eval(Aliased, :(v -> @match v begin
        $(Meta.parse(hint)) => 1
        _ => 0
    end))
    @test Base.invokelatest(fn, Elsewhere.Far.Away()) == 1
    @test Match.show_space(
        Match.lower(only(arms_of(:(
            begin
                Shape.Empty() => 0
            end
        ))), Match.REACH, budget()),
        @__MODULE__,
    ) == "Shape.Empty()"
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

"Which `UNIVERSE` values `pattern` matches."
function instances(pattern::Expr)::Vector{Bool}
    fn = compile(Expr(:block, :($pattern => true), :(_ => false)))
    return [Base.invokelatest(fn, value) for value in UNIVERSE]
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

        grid_reached = reached[eachindex(UNIVERSE)]
        witnesses = Match.missing_patterns(cases, 10, budget())
        falls_through = 0 in grid_reached
        names_variant = any(arm -> occursin("Grid.", string(arm.args[2])), arms)
        # without guards, every `Grid` value a witness matches falls through
        if mode !== :guarded
            @test isempty(witnesses) || falls_through
            for witness in witnesses
                hits = instances(Meta.parse(Match.show_space(witness, @__MODULE__)))
                @test any(hits)
                @test all(grid_reached[hits] .== 0)
            end
        end
        # without unreadable patterns, a `Grid` fall-through is always reported
        mode !== :blind && names_variant && @test !falls_through || !isempty(witnesses)
    end
end
