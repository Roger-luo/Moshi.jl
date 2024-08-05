module DynamicSumTypesBench

using Random
using DynamicSumTypes

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

main_each(x::A) = AT(B(x.common_field + 1, x.a, x.b, x.b))
main_each(x::B) = AT(C(x.common_field - 1, x.b, isodd(x.a), x.b, x.d))
main_each(x::C) = AT(D(x.common_field + 1, isodd(x.common_field) ? "hi" : "bye"))
main_each(x::D) = AT(A(x.common_field - 1, x.b == "hi", x.common_field))

end # module
