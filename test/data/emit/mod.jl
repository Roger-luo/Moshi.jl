using Test

@testset "basic" begin
    include("basic.jl")
    include("unityper.jl")
    include("selfref.jl")
end

@testset "generic" begin
    include("option.jl")
    include("uninferable.jl")
end
