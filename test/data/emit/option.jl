using Test
using Moshi.Data: @data, isa_variant

@data Option{T} begin
    Some(T)
    None
end

@testset "Option{T}" begin
    @testset "cons" begin
        x = Option.Some(1)
        @test isa_variant(x, Option.Some)
        x = Option.Some{Float64}(1)
        @test isa_variant(x, Option.Some{Float64})
        x = Option.None()
        @test isa_variant(x, Option.None)
        @test !isa_variant(Option.None{Float64}(), Option.None{Int})
        @test isa_variant(Option.None{Float64}(), Option.None{Float64})
    end

    function foo(x::Option.Type{Int})::Option.Type{Int}
        if isa_variant(x, Option.Some)
            return Option.None()
        else
            return Option.Some(2)
        end
    end

    @testset "convert" begin
        isa_variant(foo(Option.Some(1)), Option.None{Int})
        isa_variant(foo(Option.Some(1)), Option.None{Float64})
    end
end # Option{T}
