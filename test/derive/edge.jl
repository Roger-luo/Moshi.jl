using Test
using Moshi.Data: @data
using Moshi.Derive: @derive, Hash

@data CacheFirst begin
    struct A
        cache::Hash.Cache = Hash.Cache()
        x::Int
    end
end
@derive CacheFirst[Hash, Eq]

@data CacheMiddle begin
    struct A
        x::Int
        cache::Hash.Cache = Hash.Cache()
        y::Int
    end
end
@derive CacheMiddle[Hash, Eq]

@data CacheOnly begin
    struct A
        cache::Hash.Cache = Hash.Cache()
    end
end
@derive CacheOnly[Hash, Eq]

struct StructCacheMiddle
    x::Int
    cache::Hash.Cache
    y::Int
end
StructCacheMiddle(x, y) = StructCacheMiddle(x, Hash.Cache(), y)
@derive StructCacheMiddle[Hash, Eq]

@testset "Hash.Cache field position" begin
    @test hash(CacheOnly.A()) == hash(CacheOnly.A())
    @test hash(StructCacheMiddle(1, 2)) == hash(StructCacheMiddle(1, 2))
    @test hash(StructCacheMiddle(1, 2)) != hash(StructCacheMiddle(1, 3))
    @test_broken hash(CacheFirst.A(; x=1)) != hash(CacheFirst.A(; x=2))
    @test_broken hash(CacheMiddle.A(; x=1, y=2)) == hash(CacheMiddle.A(; x=1, y=2))
    @test_broken hash(CacheMiddle.A(; x=1, y=2)) != hash(CacheMiddle.A(; x=1, y=3))
end

@data Either begin
    Left(Int)
    Right(Int)
end
@derive Either[Hash, Eq]

@testset "variants with equal fields differ" begin
    @test Either.Left(1) != Either.Right(1)
    @test hash(Either.Left(1)) != hash(Either.Right(1))
end

@data Tree begin
    Leaf(Int)
    Node(Vector{Tree.Type})
end
@derive Tree[Hash, Eq, Show]

@testset "self reference inside a container" begin
    @test Tree.Node([Tree.Leaf(1)]) == Tree.Node([Tree.Leaf(1)])
    @test hash(Tree.Node([Tree.Leaf(1)])) == hash(Tree.Node([Tree.Leaf(1)]))
    @test sprint(show, Tree.Leaf(1)) == "Tree.Leaf(1)"
    # by design the wrapper type is named `typeof(Tree)`, see issue #17
    @test nameof(Tree.Type) === Symbol("typeof(Tree)")
    @test occursin("typeof(Tree)", sprint(show, Tree.Node([Tree.Leaf(1)])))
end

@data Floats begin
    A(Float64)
end
@derive Floats[Hash, Eq]

@testset "== and isequal follow the fields" begin
    @test Floats.A(NaN) != Floats.A(NaN)
    @test isequal(Floats.A(NaN), Floats.A(NaN))
    @test Floats.A(0.0) == Floats.A(-0.0)
    @test !isequal(Floats.A(0.0), Floats.A(-0.0))
end

@data Maybe begin
    A(Any)
end
@derive Maybe[Eq]

struct MaybeStruct
    x::Any
end
@derive MaybeStruct[Eq]

@testset "missing fields propagate through ==" begin
    @test isequal(Maybe.A(missing), Maybe.A(missing))
    @test isequal(MaybeStruct(missing), MaybeStruct(missing))
    @test_broken ismissing(Maybe.A(missing) == Maybe.A(missing))
    @test_broken ismissing(MaybeStruct(missing) == MaybeStruct(missing))
end
