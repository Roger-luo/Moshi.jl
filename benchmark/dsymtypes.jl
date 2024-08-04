module DynamicSumTypesBench

using Random
using DynamicSumTypes

@kwdef struct A
    common_field::Int = 1
    a::Bool = true
    b::Int = 10
end
@kwdef struct B
    common_field::Int = 1
    c::Int = 1
    d::Float64 = 1.0
    e::Complex = 1.0 + 1.0im
end
@kwdef struct C
    common_field::Int = 1
    f::Float64 = 2.0
    g::Bool = false
    h::Float64 = 3.0
    i::Complex{Float64} = 1.0 + 2.0im
end
@kwdef struct D
    common_field::Int = 1
    l::Any = "hi"
end

@sumtype AT(A,B,C,D)

function generate(len::Int)
    rng = MersenneTwister(123)
    return rand(
        MersenneTwister(123),
        (AT(A()), AT(B()), AT(C()), AT(D())),
        len,
    )
end

function main!(xs)
    for i in eachindex(xs)
        @inbounds xs[i] = main_each(variant(xs[i]))
    end
end

main_each(x::A) = AT(B(x.common_field+1, x.a, x.b, x.b))
main_each(x::B) = AT(C(x.common_field-1, x.d, isodd(x.c), x.d, x.e))
main_each(x::C) = AT(D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye"))
main_each(x::D) = AT(A(x.common_field-1, x.l=="hi", x.common_field))

end # module
