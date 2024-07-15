using Test
using Moshi.Match: @match

@test @match "aaa" begin
    Regex("aaa") => true
end
