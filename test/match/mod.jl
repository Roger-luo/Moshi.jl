using Test

@testset "scan" begin
    include("scan.jl")
end

@testset "examples" begin
    include("examples/basic.jl")
end
