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
