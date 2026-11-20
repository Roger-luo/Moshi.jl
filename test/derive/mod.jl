module TestHash
using Test
@testset "hash" begin
    include("hash.jl")
end
end # hash

module TestDeriveStruct
using Test
@testset "struct" begin
    include("struct.jl")
end
end # struct

module TestDeriveEdge
using Test
@testset "edge" begin
    include("edge.jl")
end
end # edge
