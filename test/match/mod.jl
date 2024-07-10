using Test

@testset "scan" begin
    include("scan.jl")
end

@testset "examples" begin
    include("examples/basic.jl")
    include("examples/data.jl")
end

@testset "exception" begin
    include("exception.jl")
end
