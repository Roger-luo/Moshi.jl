# Deterministic performance-regression guards.
#
# Unlike wall-clock benchmarks (which are noisy on CI runners and live in
# benchmark/benchmarks.jl), these assert metrics that are reproducible
# bit-for-bit across machines and Julia versions: type inference and
# allocation *scaling*. They run as part of the normal `Pkg.test()` suite so a
# regression hard-fails CI.
module PerfRegressionTests

using Test
using Moshi.Data: @data
using Moshi.Match: @match

# Reconstructs the linked list from issue #15:
# https://github.com/Roger-luo/Moshi.jl/issues/15
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

# Measure allocations behind a function barrier. Measuring `@allocated` at
# global scope would count spurious allocations from boxed global-variable
# access and mask the real signal.
count_allocs(l) = @allocated listsum(l)

@testset "issue #15: @match linked-list sum stays type-stable & non-scaling" begin
    small = makelist(16)
    large = makelist(4096)

    # Force compilation and check correctness.
    @test listsum(small) == sum(1:16)
    @test listsum(large) == sum(1:4096)

    # Type stability: the recursive @match must infer a concrete return type.
    @test (@inferred listsum(small)) == sum(1:16)

    # The #15 pathology was O(n) allocation growth (~195 allocs / 3 KiB for a
    # 100-element list). A healthy implementation allocates a small *constant*
    # amount regardless of list length, so allocations must not scale with n.
    a_small = count_allocs(small)
    a_large = count_allocs(large)
    @test a_large == a_small
    # Backstop: the constant must stay tiny. #15 would blow well past this for a
    # 4096-element list.
    @test a_large <= 64
end

end # module PerfRegressionTests
