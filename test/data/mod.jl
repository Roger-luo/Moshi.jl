using Test

@testset "cons" begin
    include("cons.jl")
end

@testset "show" begin
    include("show.jl")
end

@testset "emit" begin
    include("emit/mod.jl")
end

@testset "exception" begin
    include("exception.jl")
end

module TestDataEdge
using Test
@testset "edge" begin
    include("edge.jl")
end
end # module
