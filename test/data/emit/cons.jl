using Test
using Moshi.Data: @data

@data SelfRefCons begin
    struct A
        a::Int
        b::Float64 = sin(a) + 1
    end
end

@test SelfRefCons.A(a=1).b ≈ sin(1) + 1
