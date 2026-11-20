using Test
using Moshi.Data: @data
using Moshi.Match: @match, PatternSyntaxError

@test sprint(showerror, PatternSyntaxError("X")) == "X"
@test sprint(showerror, PatternSyntaxError("X", LineNumberNode(3, :file))) ==
    "X\n  at file:3"

@data OrBind begin
    One(Int)
    Two(Int, Int)
    Pair(Any, Any)
end

"The `PatternSyntaxError` expanding `ex` throws."
function expand_error(ex)
    err = try
        macroexpand(@__MODULE__, ex)
    catch err
        err
    end
    err isa LoadError && (err = err.error)
    return err
end

@testset "`||` branches bind the same variables" begin
    err = expand_error(:(@match x begin
        OrBind.One(a) || OrBind.Two(_, b) => a
        _ => 0
    end))
    @test err isa PatternSyntaxError
    @test occursin("`a` is bound only on the left", err.msg)
    @test occursin("`b` is bound only on the right", err.msg)
    @test err.source.line > 0
    # nested `||` are checked at each level
    @test expand_error(:(@match x begin
        OrBind.Pair(c, (OrBind.One(a) || OrBind.Two(a, _)) || OrBind.Two(_, a)) => a
    end)) isa Expr
    @test expand_error(:(@match x begin
        OrBind.Pair(c, (OrBind.One(a) || OrBind.Two(_, b)) || OrBind.Two(_, a)) => a
    end)) isa PatternSyntaxError
    both_sides(x) = @match x begin
        OrBind.One(a) || OrBind.Two(_, a) => a
        _ => 0
    end
    @test both_sides(OrBind.One(1)) == 1
    @test both_sides(OrBind.Two(1, 2)) == 2
end

@testset "a name repeated in one `||` branch tests equality in that branch" begin
    # issue #99
    repeated(x) = @match x begin
        OrBind.Two(a, a) || OrBind.One(a) => a
        _ => 0
    end
    @test repeated(OrBind.Two(1, 1)) == 1
    @test repeated(OrBind.Two(1, 2)) == 0
    @test repeated(OrBind.One(3)) == 3

    # a name bound before the `||`, tested again on one side only
    outer(x) = @match x begin
        OrBind.Pair(a, OrBind.Two(a, b) || OrBind.One(b)) => b
        _ => 0
    end
    @test outer(OrBind.Pair(1, OrBind.Two(1, 2))) == 2
    @test outer(OrBind.Pair(1, OrBind.Two(5, 2))) == 0
    @test outer(OrBind.Pair(1, OrBind.One(4))) == 4

    # a guard sees the binding whichever side matched
    guarded(x) = @match x begin
        (OrBind.Two(a, a) || OrBind.One(a)) && if a > 0
        end => a
        _ => 0
    end
    @test guarded(OrBind.Two(2, 2)) == 2
    @test guarded(OrBind.One(5)) == 5
    @test guarded(OrBind.One(-1)) == 0
end
