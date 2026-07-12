# Performance-regression benchmark suite for Moshi.
#
# This file follows the BenchmarkTools.jl / AirspeedVelocity.jl convention: it
# must define a top-level `const SUITE = BenchmarkGroup()`. It is run in CI by
# `.github/workflows/Benchmarks.yml`, which compares the PR against the default
# branch and posts a time/memory table on the pull request.
#
# The suite is intentionally self-contained (only BenchmarkTools + Moshi +
# Random, see benchmark/Project.toml) so the CI job stays fast. The broader
# cross-package comparison harness that produces docs/public/benchmark.svg lives
# in benchmark/comparison/ with its own (heavier) environment.

using BenchmarkTools

const SUITE = BenchmarkGroup()

# ---------------------------------------------------------------------------
# Linked list `sum` — regression guard for issue #15.
#
# A recursive `@match` over a generic linked list must be type-stable and
# allocation-free. The original report measured ~3 KiB / 195 allocations for a
# 100-element list; it should be 0.
# ---------------------------------------------------------------------------
module ListBench

using Moshi.Data: @data
using Moshi.Match: @match

@data List{T} begin
    Nil
    Cons(T, List{T})
end

function listsum(l::List.Type{T}; init=zero(T)) where {T}
    @match l begin
        List.Nil() => init
        List.Cons(head, tail) => head + listsum(tail; init)
    end
end

makelist(n) = foldr(List.Cons, 1:n; init=List.Nil{Int}())

end # module ListBench

let g = BenchmarkGroup()
    for n in (100, 1000)
        l = ListBench.makelist(n)
        g["sum n=$n"] = @benchmarkable ListBench.listsum($l)
    end
    SUITE["linked_list"] = g
end

# ---------------------------------------------------------------------------
# Heterogeneous ADT construction + `@match` dispatch over a vector.
#
# Exercises constructor allocation and variant dispatch on a mixed-variant
# workload — a representative "real" Moshi usage pattern.
# ---------------------------------------------------------------------------
module TransformBench

using Random
using Moshi.Data: @data
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

generate(len::Int) = rand(MersenneTwister(123), (AT.A(), AT.B(), AT.C(), AT.D()), len)

function transform!(xs)
    for i in eachindex(xs)
        x = xs[i]
        xs[i] = @match x begin
            AT.A(; common_field, a, b) => AT.B(common_field + 1, a, b, b)
            AT.B(; common_field, a, b, d) => AT.C(common_field - 1, b, isodd(a), b, d)
            AT.C(; common_field) =>
                AT.D(common_field + 1, isodd(common_field) ? "hi" : "bye")
            AT.D(; common_field, b) => AT.A(common_field - 1, b == "hi", common_field)
        end
    end
    return xs
end

end # module TransformBench

let g = BenchmarkGroup()
    for n in (100, 1000)
        xs = TransformBench.generate(n)
        g["transform n=$n"] = @benchmarkable TransformBench.transform!(x) setup = (
            x = copy($xs)
        )
    end
    SUITE["adt_transform"] = g
end
