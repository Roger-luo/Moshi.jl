module UnityperBench

using Random
using Unityper

@compactify begin
    @abstract struct AT
        common_field::Int = 0
    end
    struct A <: AT
        a::Bool = true
        b::Int = 10
    end
    struct B <: AT
        a::Int = 1
        b::Float64 = 1.0
        d::Complex = 1 + 1.0im # not isbits
    end
    struct C <: AT
        b::Float64 = 2.0
        d::Bool = false
        e::Float64 = 3.0
        k::Complex{Real} = 1 + 2im # not isbits
    end
    struct D <: AT
        b::Any = "hi" # not isbits
    end
end

function generate(len::Int)
    rng = Random.MersenneTwister(123)
    return rand(rng, (A(), B(), C(), D()), len)
end

function main!(xs)
    for i in eachindex(xs)
        @inbounds x = xs[i]
        @inbounds xs[i] = @compactified x::AT begin
            A => B(; common_field=x.common_field + 1, a=x.a, b=x.b, d=x.b)
            B => C(; common_field=x.common_field - 1, b=x.b, d=isodd(x.a), e=x.b, k=x.d)
            C =>
                D(; common_field=x.common_field + 1, b=isodd(x.common_field) ? "hi" : "bye")
            D => A(; common_field=x.common_field - 1, a=x.b == "hi", b=x.common_field)
        end
    end
end

end # module
