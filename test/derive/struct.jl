using Test
using Moshi.Derive: @derive, Hash

struct Point
    x::Int
    y::Int
end
@derive Point[Hash, Eq, Show]

struct Cached
    x::Int
    y::Int
    cache::Hash.Cache
end
Cached(x, y) = Cached(x, y, Hash.Cache())
@derive Cached[Hash, Eq]

struct Wrap{T}
    value::T
end
@derive Wrap[Hash, Eq, Show]

@testset "hash" begin
    a = Point(1, 2)
    b = Point(1, 2)
    c = Point(1, 3)
    @test hash(a) == hash(b)
    @test hash(a) != hash(c)
    @test hash(a) == hash(a, zero(UInt)) # deterministic on default seed
end

@testset "eq" begin
    a = Point(1, 2)
    b = Point(1, 2)
    c = Point(1, 3)
    @test a == b
    @test a != c
    @test isequal(a, b)
    @test !isequal(a, c)
end

@testset "show" begin
    @test sprint(show, Point(1, 2)) == "Point(1, 2)"
    @test sprint(show, Wrap("s")) == "Wrap(\"s\")"
    @test sprint(show, Wrap(1)) == "Wrap(1)"
end

@testset "hash cache" begin
    a = Cached(1, 2)
    b = Cached(1, 2)
    @test !a.cache.is_set
    @test hash(a) == hash(b)
    @test a.cache.is_set
    @test a.cache[] == hash(a)

    # both caches set -> fast path compares cached hashes
    @test a == b
    @test isequal(a, b)

    # caches unset -> falls back to field-by-field comparison
    c = Cached(1, 2)
    d = Cached(1, 2)
    e = Cached(1, 3)
    @test !c.cache.is_set
    @test c == d
    @test isequal(c, d)
    @test c != e
    @test !isequal(c, e)
end

@testset "parametric struct" begin
    a = Wrap(1)
    b = Wrap(1)
    @test hash(a) == hash(b)
    @test a == b
    @test Wrap(1) != Wrap(2)
end
