using Test
using Moshi.Data: @data, variant_type
using Moshi.Derive: @derive

@data Message{T} begin
    Quit
    struct Move
        x::Int
        y::Int
    end

    Write(String)
    ChangeColor(Int, Int, Int)
end

@derive Message[Show]

@testset "not inferrable" begin
    x = Message.Quit()
    @test convert(Message.Type{Int}, x) isa Message.Type{Int}
    @test_throws MethodError Message.Move(1, 2)
    @test variant_type(x) == Message.Quit{Union{}}
    x = Message.Move{Float64}(1, 2)
    @test sprint(show, x) == "Message.Move{Float64}(x=1, y=2)"
    @test variant_type(x) == Message.Move{Float64}
end # not inferrable
