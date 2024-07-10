module TestDataTypes

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

    @test (1, ) == @match Foo(1, 2, 3) begin
        Foo(x) => (x, )
    end
end # testset

@data Message begin
    Quit
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
        Message.Move(;x, y) => (x, y)
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

end # module
