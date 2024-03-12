using Test
using Moshi.Match: @match

@match (1, 2) begin
    (x, 2) => x
end
