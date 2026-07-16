using Test
using Moshi.Match: @match

@test @match 1 _::Int => true

@test 1 == @match 1 begin
    1 => 1
    _ => error("no match")
end

@test 1 == @match 1 begin
    _ => 1
    _ => error("no match")
end

@test 3 == @match [1, 2, 2] begin
    [1, x, x] => x + 1
end

@test [2, 2] == @match [1, 2, 2] begin
    [1, xs...] => xs
end

@test "a" == @match [1, 2.0, "a"] begin
    [1, x::Int, y::String] => x
    [1, x::Real, y::String] => y
end

@test "a" == @match [1, 2.0, "a"] begin
    [1, _::Float64, y::String] => y
end

@test :b == @match Int[1, 2] begin
    Any[1, 2] => :a
    Int[_, _] => :b
end

# https://github.com/Roger-luo/Moshi.jl/issues/36
# `Indexable[...]` and an abstract-array head (`AbstractVector[...]`) match any
# `AbstractVector` via the array interface, while bare `[...]` stays `Vector`-only.
@test 2 == @match view([1, 2, 3], :) begin
    Indexable[1, x, 3] => x
    _ => nothing
end
@test 2 == @match view([1, 2, 3], :) begin
    AbstractVector[1, x, 3] => x
    _ => nothing
end
@test nothing === @match view([1, 2, 3], :) begin
    [1, x, 3] => x # a bare vector pattern must NOT match a `SubArray`
    _ => nothing
end
# both spellings still match a plain `Vector`
@test 2 == @match [1, 2, 3] begin
    Indexable[1, x, 3] => x
    _ => nothing
end
@test 2 == @match [1, 2, 3] begin
    AbstractVector[1, x, 3] => x
    _ => nothing
end
# a range is an `AbstractVector` too
@test 3 == @match 1:2:5 begin
    Indexable[1, x, 5] => x
    _ => nothing
end
# splats work over the abstract container
@test [2, 3] == @match view([1, 2, 3], :) begin
    Indexable[1, xs...] => xs
    _ => nothing
end
@test [2, 3] == @match view([1, 2, 3], :) begin
    AbstractVector[1, xs...] => xs
    _ => nothing
end
# a concrete head still means element type: `Int[...]` is `Vector{Int}`, not a container
@test nothing === @match view([1, 2, 3], :) begin
    Int[1, x, 3] => x
    _ => nothing
end
# typed splats are still respected under an abstract container head
@test_throws ErrorException @match view([1.0, 2, 3], :) begin
    AbstractVector[1, xs::Int...] => xs
end
@test [2.0, 3.0] == @match view([1.0, 2, 3], :) begin
    AbstractVector[1, xs::Float64...] => xs
end

# a minimal non-1-based AbstractVector: collection patterns must index relative to
# `firstindex`/`lastindex`, not hard-coded `1`, so offset vectors deconstruct correctly.
struct OffsetVec{T} <: AbstractVector{T}
    data::Vector{T}
    off::Int # elements live at indices (off + 1):(off + length(data))
end
Base.size(v::OffsetVec) = size(v.data)
Base.axes(v::OffsetVec) = (v.off .+ only(axes(v.data)),)
Base.getindex(v::OffsetVec, i::Int) = v.data[i - v.off]
Base.IndexStyle(::Type{<:OffsetVec}) = IndexLinear()

@test firstindex(OffsetVec([10, 20, 30], 5)) == 6
@test 20 == @match OffsetVec([10, 20, 30], 5) begin
    Indexable[10, x, 30] => x
    _ => nothing
end
@test 20 == @match OffsetVec([10, 20, 30], 5) begin
    AbstractVector[10, x, 30] => x
    _ => nothing
end
# leading element + trailing splat, both anchored off `firstindex`/`lastindex`
@test [20, 30] == @match OffsetVec([10, 20, 30], 5) begin
    Indexable[10, xs...] => xs
    _ => nothing
end
@test [10, 20] == @match OffsetVec([10, 20, 30], 5) begin
    Indexable[xs..., 30] => xs
    _ => nothing
end
@test [20] == @match OffsetVec([10, 20, 30], 5) begin
    Indexable[10, xs..., 30] => xs
    _ => nothing
end

VAL = 123
@test "a" == @match [1, VAL, "a"] begin
    [1, $VAL, y::String] => y
end

@test "a" == @match [1, 2, "a"] begin
    [1, x, y::String] && if x == 2
    end => y
end

@test "a" == @match [1, 2, "a"] begin
    [1, 1.0, y::String] || [1, 2, y::String] => y
end

# tuple
@test 3 == @match (1, 2, 2) begin
    (1, x, x) => x + 1
end

@test (2, 2) == @match (1, 2, 2) begin
    (1, xs...) => xs
end

@test "a" == @match (1, 2.0, "a") begin
    (1, x::Int, y::String) => x
    (1, x::Real, y::String) => y
end

@test "a" == @match (1, 2.0, "a") begin
    (1, _::Float64, y::String) => y
end

VAL = 123
@test "a" == @match (1, VAL, "a") begin
    (1, $VAL, y::String) => y
end

@test "a" == @match (1, 2, "a") begin
    (1, x, y::String) && if x == 2
    end => y
end

# # TODO: error on unbalanced patterns about missing y
# @match [1, 2, "a"] begin
#     [1, 1.0, y::String] || [1, 2, ::String] => y
# end

@test (2, 3) == @match (1.0, 2, 3) begin
    (1, xs::Int...) => xs
end

@test_throws ErrorException @match (1.0, 2, 3) begin
    (1, xs::Float64...) => xs
end

@test_throws ErrorException @match [1.0, 2, 3] begin
    [1, xs::Int...] => xs
end

@test [2.0, 3.0] == @match [1.0, 2, 3] begin
    [1, xs::Float64...] => xs
end

# https://github.com/Roger-luo/Moshi.jl/issues/48
# the type annotation on a splat must be respected, both for the `T[...]` (Ref)
# and the `[...]` (Vector) syntax, and must match element subtypes/supertypes
# rather than requiring an exact `eltype` match.
@test "second" == @match [1, [2, 3]] begin
    Any[a::Int, b::String...] => "first"
    Any[a::Int, b::Vector{Int}...] => "second"
end

@test "second" == @match [1, [2, 3]] begin
    [a::Int, b::String...] => "first"
    [a::Int, b::Vector{Int}...] => "second"
    _ => "third"
end

# a splat annotation on a `Ref` pattern must not be silently compiled away
@test_throws UndefVarError @match [1, [2, 3]] begin
    Any[a::Int, b::ThisTypeIsNotDefined...] => "sure"
end

# splats match supertypes of the elements, like other Moshi patterns
@test "matched" == @match Union{Int,Vector{Int}}[1, [2, 3]] begin
    [a::Int, b::String...] => "nope"
    [a::Int, b::Any...] => "matched"
end

# a splat matching zero elements trivially satisfies its annotation
@test [] == @match [1] begin
    [a::Int, b::String...] => b
end

struct Foo
    x::Int
    y::Int
    z::Float64
end

const foo = Foo(1, 2, 3.0)

@test @match foo begin
    Foo(foo.x, foo.y, foo.z) => true
    _ => false
end
