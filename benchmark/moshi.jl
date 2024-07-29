using Test
using Moshi.Data: Data, @data, isa_variant

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
    for i in eachindex(xs)
        x = xs[i]
        data = getfield(x, :data)
        xs[i] = if data isa AT.var"##Storage#A"
            AT.B(data.common_field + 1, data.a, data.b, data.b)
        elseif data isa AT.var"##Storage#B"
            AT.C(data.common_field - 1, data.b, isodd(data.a), data.b, data.d)
        elseif data isa AT.var"##Storage#C"
            AT.D(data.common_field + 1, isodd(data.common_field) ? "hi" : "bye")
        else
            AT.A(data.common_field - 1, data.b == "hi", data.common_field)
        end
    end
end

using Random
rng = Random.MersenneTwister(123)
xs = rand(rng, (AT.A(), AT.B(), AT.C(), AT.D()), 10000)

using BenchmarkTools
display(@benchmark foo!($xs))
