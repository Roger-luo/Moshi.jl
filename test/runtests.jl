using Test

@testset "data" begin
    include("data/mod.jl")
end

@testset "match" begin
    include("match/mod.jl")
end

@testset "derive" begin
    include("derive/mod.jl")
end
