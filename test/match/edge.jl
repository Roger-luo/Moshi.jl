using Test
using Moshi.Data: @data
using Moshi.Match: @match, PatternSyntaxError

"The error expanding `ex` throws, or the expansion when it does not throw."
function expand_error(ex)
    err = try
        macroexpand(@__MODULE__, ex)
    catch err
        err
    end
    err isa LoadError && (err = err.error)
    return err
end

"`ex` evaluated in this module, so a macro that fails to expand fails at run time."
run_expr(ex) = Core.eval(@__MODULE__, ex)

@testset "splats" begin
    @test (1, (2, 3), 4) == @match (1, 2, 3, 4) begin
        (a, xs..., b) => (a, xs, b)
    end
    @test (1, (), 2) == @match (1, 2) begin
        (a, xs..., b) => (a, xs, b)
    end
    @test :short == @match (1,) begin
        (a, xs..., b) => (a, xs, b)
        _ => :short
    end
    @test :short == @match [1] begin
        [a, xs..., b] => (a, xs, b)
        _ => :short
    end
    @test [2, 3] == @match [1, 2, 3] begin
        [a, (xs::Int)...] => xs
    end
    @test expand_error(:(@match [1] begin
        [xs..., ys...] => 1
    end)) isa Exception
end

@testset "tuple and vector shapes" begin
    @test :three == @match (1, 2, 3) begin
        (a, b) => :two
        (a, b, c) => :three
    end
    @test :other == @match [1, 2] begin
        (a, b) => :tuple
        _ => :other
    end
    @test :other == @match (1, 2) begin
        [a, b] => :vector
        _ => :other
    end
    @test :empty == @match () begin
        () => :empty
    end
    @test :other == @match (1,) begin
        () => :empty
        _ => :other
    end
    @test :other == @match 1:3 begin
        [a, b, c] => :vector
        _ => :other
    end
end

@testset "literals compare with ==" begin
    @test :one == @match 1.0 begin
        1 => :one
        _ => :other
    end
    @test :zero == @match -0.0 begin
        0.0 => :zero
        _ => :other
    end
    @test :bool == @match 1 begin
        true => :bool
        _ => :other
    end
    @test :other == @match NaN begin
        $(NaN) => :nan
        _ => :other
    end
    @test :diff == @match (NaN, NaN) begin
        (x, x) => :same
        _ => :diff
    end
end

@testset "literal patterns against missing" begin
    @test_broken :other == @match missing begin
        1 => :one
        _ => :other
    end
    @test_broken :no == @match [missing, 1] begin
        [1, _] => :one
        _ => :no
    end
    @test_broken :diff == @match (missing, missing) begin
        (x, x) => :same
        _ => :diff
    end
end

@testset "`nothing` as a literal pattern" begin
    @test 0 == @match nothing begin
        ::Nothing => 0
    end
    @test 0 == @match nothing begin
        $(nothing) => 0
    end
    @test_broken 0 == run_expr(:(@match nothing begin
        nothing => 0
        _ => 1
    end))
end

@testset "Int128 literal" begin
    @test_broken :max == run_expr(:(@match typemax(Int128) begin
        170141183460469231731687303715884105727 => :max
        _ => :no
    end))
end

struct Point
    x::Int
    y::Int
end

@data Named begin
    struct P
        x::Int
        y::Int
    end
end

@testset "keyword fields in call patterns" begin
    @test 2 == @match Named.P(1, 2) begin
        Named.P(; y) => y
    end
    @test :two == @match Named.P(1, 2) begin
        Named.P(; y=2) => :two
        _ => :other
    end
    @test_broken 2 == run_expr(:(@match Point(1, 2) begin
        Point(; y) => y
    end))
    @test_broken :two == run_expr(:(@match Point(1, 2) begin
        Point(; y=2) => :two
        _ => :other
    end))
end

@testset "guards with a non-call condition" begin
    @test :guard == @match 1 begin
        x && if x > 0
        end => :guard
    end
    flag = true
    @test :guard == @match 1 begin
        x && if flag
        end => :guard
        _ => :no
    end
    flag = false
    @test :no == @match 1 begin
        x && if flag
        end => :guard
        _ => :no
    end
    @test :no == @match 1 begin
        x && if false
        end => :guard
        _ => :no
    end
    @test :guard == @match 1 begin
        x && if true
        end => :guard
    end
    # a pattern variable as the whole condition
    pick(v) = @match v begin
        (b, x) && if b
        end => x
        (_, x) => -x
    end
    @test pick((true, 2)) == 2
    @test pick((false, 2)) == -2
    # a guard covers nothing, even an always-true one
    @test_logs Core.eval(@__MODULE__, :(@match 1 begin
        x && if true
        end => 1
        x => 2
    end))
end

@testset "malformed match bodies throw PatternSyntaxError" begin
    @test expand_error(:(@match 1 begin end)) isa Expr # fails when run
    @test_broken expand_error(:(@match 1 begin
        1 -> 2
    end)) isa PatternSyntaxError
    @test_broken expand_error(:(@match 1 x)) isa PatternSyntaxError
end

abstract type Shape end
struct Square <: Shape
    side::Int
end

@testset "call patterns whose head is not a concrete constructor" begin
    # either an error at run time or a `PatternSyntaxError`, not an internal error
    reported(err) = err isa Union{Expr,PatternSyntaxError}
    @test_broken reported(expand_error(:(@match 3 begin
        1:5 => :range
        _ => :other
    end)))
    @test_broken reported(expand_error(:(@match 1 begin
        sin(x) => x
        _ => :other
    end)))
    @test_broken reported(expand_error(:(@match 1 // 2 begin
        1 // 2 => :half
        _ => :other
    end)))
    @test_broken reported(expand_error(:(@match Square(1) begin
        Shape(x) => x
        _ => :other
    end)))
end

@testset "keyword-like pattern `(a = 1)` does not overflow the stack" begin
    # skipped, not run: the overflow can hang the test process. It comes from printing a
    # `Pattern.Kw`, which `show(::IO, ::Pattern.Type)` has no case for.
    @test_skip expand_error(:(@match 1 begin
        (a = 1) => 1
        _ => 0
    end)) isa PatternSyntaxError
    @test_skip expand_error(:(@match (1, 2) begin
        (a=1, b) => 1
        _ => 0
    end)) isa PatternSyntaxError
end

@testset "scoping" begin
    @test 100 == let a = 100
        @match 1 begin
            a => a
        end
        a
    end
    @test 3 == (@match (1, 2) begin
        (a, b) => () -> a + b
    end)()
    count = Ref(0)
    next() = (count[] += 1; (1, 2))
    @test :b == @match next() begin
        (2, _) => :a
        (1, x) => :b
    end
    @test count[] == 1
end

@data List begin
    Nil()
    Cons(Int, List.Type)
end

@testset "deeply nested pattern" begin
    ex = :(List.Nil())
    for i in 1:100
        ex = :(List.Cons($i, $ex))
    end
    value = run_expr(ex)
    @test :deep == run_expr(:(@match $value begin
        $ex => :deep
        _ => :no
    end))
end
