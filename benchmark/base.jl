using Test
using Moshi.Data: Data, @data, isa_variant

Base.@kwdef struct A
    common_field::Int = 0
    a::Bool = true
    b::Int = 10
end
Base.@kwdef struct B
    common_field::Int = 0
    a::Int = 1
    b::Float64 = 1.0
    d::Complex = 1 + 1.0im # not isbits
end
Base.@kwdef struct C
    common_field::Int = 0
    b::Float64 = 2.0
    d::Bool = false
    e::Float64 = 3.0
    k::Complex{Real} = 1 + 2im # not isbits
end
Base.@kwdef struct D
    common_field::Int = 0
    b::Any = "hi" # not isbits
end

struct Object
    data::Union{A,B,C,D}
end

function foo!(xs)
    for i in eachindex(xs)
        x = xs[i]
        x = x.data
        xs[i] = if x isa A
            Object(B(x.common_field + 1, x.a, x.b, x.b))
        elseif x isa B
            Object(C(x.common_field - 1, x.b, isodd(x.a), x.b, x.d))
        elseif x isa C
            Object(D(x.common_field + 1, isodd(x.common_field) ? "hi" : "bye"))
        else
            Object(A(x.common_field - 1, x.b == "hi", x.common_field))
        end
    end
end

using Random
rng = Random.MersenneTwister(123)
xs = Vector{Object}(
    map(x -> rand((Object(A()), Object(B()), Object(C()), Object(D()))), 1:10000)
)
using BenchmarkTools
display(@benchmark foo!($xs))
# @code_warntype foo!(xs)
