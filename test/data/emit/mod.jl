using Test

@testset "basic" begin
    include("basic.jl")
    include("unityper.jl")
    include("selfref.jl")
end

@testset "generic" begin
    include("option.jl")
    include("uninferable.jl")
    include("named.jl")
    include("call_type.jl")
end

module TestCons
using Test
@testset "cons" begin
    include("cons.jl")
end
end # module
