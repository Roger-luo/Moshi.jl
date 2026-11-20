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
    @test occursin("`a` is bound once on the left and 0 times on the right", err.msg)
    @test occursin("`b` is bound 0 times on the left and once on the right", err.msg)
    @test err.source.line > 0
    # binding a name twice tests equality, so both sides must repeat it
    err = expand_error(:(@match x begin
        OrBind.Two(a, a) || OrBind.One(a) => a
    end))
    @test occursin("`a` is bound 2 times on the left and once on the right", err.msg)
    # nested `||` are checked at each level
    @test expand_error(:(@match x begin
        OrBind.Pair(c, (OrBind.One(a) || OrBind.Two(a, _)) || OrBind.Two(_, a)) => a
    end)) isa Expr
    @test expand_error(:(@match x begin
        OrBind.Pair(c, (OrBind.One(a) || OrBind.Two(_, b)) || OrBind.Two(_, a)) => a
    end)) isa PatternSyntaxError
    # a name bound before the `||` counts as a repeat on the side that binds it again
    @test expand_error(:(@match x begin
        OrBind.Two(c, a) && (OrBind.Two(a, _) || OrBind.Two(_, _)) => c
    end)) isa PatternSyntaxError

    both_sides(x) = @match x begin
        OrBind.One(a) || OrBind.Two(_, a) => a
        _ => 0
    end
    @test both_sides(OrBind.One(1)) == 1
    @test both_sides(OrBind.Two(1, 2)) == 2
end
