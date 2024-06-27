using Test
using Moshi.Data: @data, isa_variant, variant_fieldtypes, IllegalDispatch

@data Option{T} begin
    Some(T)
    None
end


@testset "Option{T}" begin
    @test variants(Option.Type) == (Option.Some, Option.None)
    @test variants(Option.Type{Float64}) == (Option.Some{Float64}, Option.None{Float64})
    @test variant_fieldnames(Option.Some) == (1, )
    @test variant_fieldnames(Option.Some{Float64}) == (1, )
    @test_throws IllegalDispatch variant_fieldtypes(Option.Some)
    @test variant_fieldtypes(Option.Some{Float64}) == (Float64, )


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

    @testset "reflection" begin
        @test variant_fieldtypes(Option.Some(1)) == (Int,)
        @test variant_fieldtypes(Option.Some{Int}) == (Int,)
    end
end # Option{T}
