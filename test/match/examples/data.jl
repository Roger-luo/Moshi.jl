using Test
using Moshi.Data: @data
using Moshi.Match: @match

struct Foo
    x::Int
    y::Int
    z::Float64
end

@testset "struct decons" begin
    @test (1, 2, 3) == @match Foo(1, 2, 3) begin
        Foo(x, y, z) => (x, y, z)
    end

    @test (1, 2) == @match Foo(1, 2, 3) begin
        Foo(x, y) => (x, y)
    end

    @test (1,) == @match Foo(1, 2, 3) begin
        Foo(x) => (x,)
    end
end # testset

@data Message begin
    Quit()
    struct Move
        x::Int
        y::Int
    end

    Write(String)
    ChangeColor(Int, Int, Int)
end

@test_throws ErrorException @match Message.Quit() begin
    Message.Type(x, y) => nothing
end

function foo(value::Message.Type)
    @match value begin
        Message.Move(; x, y) => (x, y)
        Message.Quit() => 0
        Message.Write(msg) => msg
        Message.ChangeColor(a) => a
    end
end

@testset "destructure ADT" begin
    @test foo(Message.Move(1, 2)) == (1, 2)
    @test foo(Message.Quit()) == 0
    @test foo(Message.Write("aaa")) == "aaa"
    @test foo(Message.ChangeColor(1, 2, 3)) == 1
end # testset

@data ADT begin
    A()
    B()
end

# https://github.com/Roger-luo/Moshi.jl/issues/43
# matching a value that is not the ADT should fall through to the wildcard
# instead of throwing IllegalDispatch.
is_a(x) = @match x begin
    ADT.A() => true
    _ => false
end

@testset "wildcard matches non-ADT value (#43)" begin
    @test is_a(ADT.A()) == true
    @test is_a(ADT.B()) == false
    @test is_a(nothing) == false
    @test is_a(1) == false
    @test is_a("string") == false
end # testset

@data Tree begin
    Leaf(Int)
    struct Branch
        left::Int
        right::Int
    end
end

# https://github.com/Roger-luo/Moshi.jl/issues/26
# broadcasting a constructor pattern over a splatted run of collection elements
@testset "broadcast pattern (#26)" begin
    # the exact example from the issue
    @test (1, 2, 3) == @match (Tree.Leaf(1), Tree.Leaf(2), Tree.Leaf(3)) begin
        (Tree.Leaf.(z...),) => z
    end

    # works inside a vector too
    @test (1, 2) == @match [Tree.Leaf(1), Tree.Leaf(2)] begin
        [Tree.Leaf.(z...)] => z
    end

    # fixed elements may surround the broadcast run
    @test (0, (1, 2), 9) == @match (0, Tree.Leaf(1), Tree.Leaf(2), 9) begin
        (a, Tree.Leaf.(z...), b) => (a, z, b)
    end

    # a broadcast run may be empty
    @test () == @match () begin
        (Tree.Leaf.(z...),) => z
        _ => :fallback
    end

    # multiple fields each collect into their own tuple
    @test ((1, 3), (2, 4)) == @match (Tree.Branch(1, 2), Tree.Branch(3, 4)) begin
        (Tree.Branch.(l..., r...),) => (l, r)
        _ => :fallback
    end

    # a wildcard argument keeps the field required but discards it
    @test (1, 3) == @match (Tree.Branch(1, 2), Tree.Branch(3, 4)) begin
        (Tree.Branch.(l..., _...),) => l
        _ => :fallback
    end

    # elements that are not the expected variant fall through
    @test :fallback == @match (Tree.Leaf(1), Tree.Branch(2, 3)) begin
        (Tree.Leaf.(z...),) => z
        _ => :fallback
    end
end # testset
