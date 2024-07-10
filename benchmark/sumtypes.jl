module SumTypeTest

using Random
using SumTypes, BenchmarkTools
@sum_type AT begin
    A(common_field::Int, a::Bool, b::Int)
    B(common_field::Int, a::Int, b::Float64, d::Complex)
    C(common_field::Int, b::Float64, d::Bool, e::Float64, k::Complex{Real})
    D(common_field::Int, b::Any)
end

foo!(xs) =
    for i in eachindex(xs)
        xs[i] = @cases xs[i] begin
            A(cf, a, b) => B(cf + 1, a, b, b)
            B(cf, a, b, d) => C(cf - 1, b, isodd(a), b, d)
            C(cf, b, d, e, k) => D(cf + 1, isodd(cf) ? "hi" : "bye")
            D(cf, b) => A(cf - 1, b == "hi", cf)
        end
    end

rng = Random.MersenneTwister(123)
xs = rand(
    rng,
    (
        A(1, true, 10),
        B(1, 1, 1.0, 1 + 1im),
        C(1, 2.0, false, 3.0, Complex{Real}(1 + 2im)),
        D(1, "hi"),
    ),
    10000,
)

display(@benchmark foo!($xs);)

end
