# Regression tests for issue #32: a field whose declared type collapses to `Any`
# in the storage struct (e.g. `Vector{Any}` or a self-referential `Vector{Self}`)
# must still be converted to its declared type on construction, otherwise the type
# assert in `getproperty`/`variant_getfield` fails.
module TestContainerConvert
using Test
using Moshi.Data: @data, variant_fieldtypes, variant_getfield

@data OptionVec{T} begin
    None()
    struct Some
        n::T
        xs::Vector{Any}
    end
end

@data AnonVec begin
    V(Vector{Any})
end

@data NamedVec begin
    struct W
        xs::Vector{Any}
    end
end

@data KwVec begin
    struct K
        xs::Vector{Any} = Any[]
    end
end

@testset "issue #32: Vector{Any} field converts on construction" begin
    @testset "generic named variant, explicit type parameter" begin
        a = OptionVec.Some{String}("hi", [1, 2])
        @test a.xs == [1, 2]
        @test a.xs isa Vector{Any}
        @test variant_fieldtypes(a) == (String, Vector{Any})
        @test a.n == "hi"
    end

    @testset "anonymous variant" begin
        v = AnonVec.V([5])
        @test getproperty(v, 1) == [5]
        @test getproperty(v, 1) isa Vector{Any}
        @test variant_getfield(v, AnonVec.V, 1) isa Vector{Any}
    end

    @testset "named variant, positional constructor" begin
        w = NamedVec.W([1, 2, 3])
        @test w.xs == [1, 2, 3]
        @test w.xs isa Vector{Any}
    end

    @testset "keyword constructor" begin
        @test KwVec.K(; xs=[1, 2]).xs isa Vector{Any}
        @test KwVec.K([1, 2]).xs isa Vector{Any}
        @test KwVec.K().xs == Any[]
    end
end

# A self-referential container field (`Vector{Self}`) stores as `Any` in the
# storage struct, so it also needs conversion so that e.g. an empty `Vector{Any}`
# literal is stored as the resolved element type.
@data Rose begin
    struct Node
        value::Int
        children::Vector{Rose}
    end
end

@data RoseP{T} begin
    struct Node
        value::T
        children::Vector{RoseP{T}}
    end
end

@testset "issue #32: self-referential Vector field converts" begin
    leaf = Rose.Node(1, [])
    @test leaf.children isa Vector{Rose.Type}
    @test isempty(leaf.children)

    tree = Rose.Node(0, [leaf])
    @test tree.children isa Vector{Rose.Type}
    @test tree.children[1].value == 1

    p = RoseP.Node{Int}(0, [])
    @test p.children isa Vector{RoseP.Type{Int}}
end

# Explicit-brace construction of a self-referential variant with a parametric
# singleton bottom (`Empty()::Type{Union{}}`) must promote the child to the
# resolved type before storing, matching the inferred constructor (issue #34).
@data Tree{T} begin
    Empty()
    Leaf(T)
    Node(T, Tree{T}, Tree{T})
end

@testset "issue #32: explicit-brace self-ref promotion" begin
    n = Tree.Node{Int}(5, Tree.Leaf(3), Tree.Empty())
    @test typeof(n) == Tree.Type{Int}
    right = variant_getfield(n, Tree.Node, 3)
    @test right isa Tree.Type{Int}
end

end # module TestContainerConvert
