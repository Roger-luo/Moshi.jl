using Test
using Moshi.Data: @data, variant_name, data_type_name

@data AT begin
    struct A
        common_field::Int = 0
        a::Bool = true
        b::Int = 10
    end
    struct B
        common_field::Int = 0
        a::Int = 1
        b::Float64 = 1.0
        d::Complex = 1 + 1.0im # not isbits
    end
    struct C
        common_field::Int = 0
        b::Float64 = 2.0
        d::Bool = false
        e::Float64 = 3.0
        k::Complex{Real} = 1 + 2im # not isbits
    end
    struct D
        common_field::Int = 0
        b::Any = "hi" # not isbits
    end
end

@testset "reflection" begin
    @test variant_name(AT.A()) === :A
    @test variant_name(AT.B()) === :B
    @test data_type_name(AT.A()) === :AT
end
