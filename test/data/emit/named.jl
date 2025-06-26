using Test
using Moshi.Data: @data

@data WithNamedVariants{T} begin
    struct First
        x::T
    end
    struct Second
        y::Vector{T}
    end
end

@testset "WithNamedVariants{T}" begin
    x = WithNamedVariants.First(1)
    @test x.x == 1
    y = WithNamedVariants.Second([1])
    @test y.y == [1]
end
