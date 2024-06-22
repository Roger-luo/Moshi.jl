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
