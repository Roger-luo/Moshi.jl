using Test

@testset "basic" begin
    include("basic.jl")
    include("unityper.jl")
    include("selfref.jl")
    include("empty_struct.jl")
end

@testset "generic" begin
    include("option.jl")
    include("uninferable.jl")
    include("named.jl")
    include("call_type.jl")
    include("singleton_promote.jl")
    include("container.jl")
end

module TestCons
using Test
@testset "cons" begin
    include("cons.jl")
end
end # module

@testset "docs" begin
    include("docs.jl")
end
