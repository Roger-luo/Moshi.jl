using Test
using Moshi.Data: Data, @data, isa_variant
using Moshi.Match: @match

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

function foo!(xs)
    @inbounds for i in eachindex(xs)
        xs[i] = @match xs[i] begin
            AT.A(cf, a, b) => AT.B(cf + 1, a, b, b)
            AT.B(cf, a, b, d) => AT.C(cf - 1, b, isodd(a), b, d)
            AT.C(cf) => AT.D(cf + 1, isodd(cf) ? "hi" : "bye")
            AT.D(cf, b) => AT.A(cf - 1, b == "hi", cf)
        end
    end
end

using Random
rng = Random.MersenneTwister(123)
xs = rand(rng, (AT.A(), AT.B(), AT.C(), AT.D()), 10000)

@code_warntype foo!(xs)

using BenchmarkTools
display(@benchmark foo!($xs))
