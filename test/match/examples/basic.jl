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
