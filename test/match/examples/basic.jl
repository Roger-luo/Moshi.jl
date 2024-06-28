using Test
using Moshi.Match: @match

@test 1 == @match 1 begin
    1 => 1
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
