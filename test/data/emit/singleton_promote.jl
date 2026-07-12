# Regression tests for issue #34: a parametric singleton such as `Tree.Empty()`
# has type `Tree.Type{Union{}}` and must be promoted to the resolved element type
# when used as a self-referential argument of another variant constructor.
module TestSingletonPromote
using Test
using Moshi.Data: @data, isa_variant, variant_getfield

@data Tree{T} begin
    Empty
    Leaf(T)
    Node(T, Tree{T}, Tree{T})
end

@testset "issue #34: singleton promotion in constructors" begin
    @testset "mixed singleton / concrete children" begin
        @test typeof(Tree.Node(5, Tree.Leaf(3), Tree.Empty())) == Tree.Type{Int}
        @test typeof(Tree.Node(5, Tree.Empty(), Tree.Leaf(3))) == Tree.Type{Int}
        @test typeof(Tree.Node(5, Tree.Empty(), Tree.Empty())) == Tree.Type{Int}
    end

    @testset "homogeneous children (no promotion needed)" begin
        @test typeof(Tree.Node(5, Tree.Leaf(1), Tree.Leaf(2))) == Tree.Type{Int}
    end

    @testset "explicit type parameter still works" begin
        @test typeof(Tree.Node(5, Tree.Leaf(3), Tree.Empty{Int}())) == Tree.Type{Int}
    end

    @testset "promoted child is stored as the resolved type" begin
        t = Tree.Node(5, Tree.Empty(), Tree.Leaf(3))
        left = variant_getfield(t, Tree.Node, 2)
        @test left isa Tree.Type{Int}
        @test isa_variant(left, Tree.Empty)
    end

    @testset "nested construction" begin
        big = Tree.Node(1, Tree.Node(2, Tree.Empty(), Tree.Leaf(3)), Tree.Empty())
        @test typeof(big) == Tree.Type{Int}
    end

    @testset "genuine type mismatch still errors" begin
        @test_throws MethodError Tree.Node(5, Tree.Leaf(3.0), Tree.Empty())
    end

    @testset "construction is type stable" begin
        f() = Tree.Node(5, Tree.Leaf(3), Tree.Empty())
        rt = Base.return_types(f, Tuple{})[1]
        @test rt == Tree.Type{Int}
        @test isconcretetype(rt)
    end
end

# A variant whose only fields are self-references: the all-bottom call must still
# resolve (to `Union{}`), while a mixed call promotes to the concrete type.
@data Lst{T} begin
    Nil
    Cons(Lst{T}, Lst{T})
end

@testset "issue #34: self-referential-only variant" begin
    @test typeof(Lst.Cons(Lst.Nil(), Lst.Nil())) == Lst.Type{Union{}}
    @test typeof(Lst.Cons(Lst.Cons(Lst.Nil(), Lst.Nil()), Lst.Nil())) == Lst.Type{Union{}}
end

end # module TestSingletonPromote
