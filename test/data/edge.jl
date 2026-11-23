using Test
using Moshi.Data: Data, @data

"The error expanding `ex` throws, or the expansion when it does not throw."
function expand_error(ex)
    err = try
        macroexpand(@__MODULE__, ex)
    catch err
        err
    end
    err isa LoadError && (err = err.error)
    return err
end

@data Pos begin
    A(Int, String)
    struct Named
        x::Int
        y::Int = x + 1
    end
end

@testset "field access" begin
    @test Pos.A(1, "a").:2 == "a"
    @test_throws ErrorException Pos.A(1, "a").:3
    @test_throws ErrorException Pos.A(1, "a").:0
    @test_throws ErrorException Pos.Named(1, 2).z
    # a later default may read an earlier field
    @test Pos.Named(; x=1).y == 2
    @test propertynames(Pos.Named(1, 2)) == (:x, :y)
    @test propertynames(Pos.A(1, "a")) == (1, 2)
end

@testset "constructor conversion" begin
    @test Pos.A(1.0, "a").:1 === 1
    @test_throws InexactError Pos.A(1.5, "a")
end

@data StorageNames begin
    struct Fields
        data::Int
        tag::Int
    end
end

@data mutable MutableStorageNames begin
    struct Fields
        data::Int
    end
end

@testset "fields named like the wrapper's own field" begin
    x = StorageNames.Fields(1, 2)
    @test (x.data, x.tag) == (1, 2)
    m = MutableStorageNames.Fields(1)
    m.data = 5
    @test m.data == 5
end

@data mutable Mut begin
    struct Point
        x::Float64
    end
end

@testset "mutable setproperty! converts" begin
    p = Mut.Point(1)
    p.x = 2
    @test p.x === 2.0
    @test_throws MethodError p.x = "s"
end

@testset "reserved and invalid definitions" begin
    @test expand_error(:(@data R1 begin
        Type(Int)
    end)) isa ArgumentError
    @test expand_error(:(@data R2 begin
        Variant()
    end)) isa ArgumentError
    @test expand_error(:(@data mutable R3 begin
        A()
    end)) isa ArgumentError
end

@testset "empty @data body reports an ArgumentError" begin
    err = try
        Core.eval(@__MODULE__, :(@data Empty begin end))
    catch err
        err
    end
    err isa LoadError && (err = err.error)
    @test_broken err isa ArgumentError
end

@data GenericDefault{T} begin
    struct A
        x::T
        y::Int = 0
    end
    struct B
        x::T
    end
end

@data GenericTree{T} begin
    Leaf()
    struct Node
        value::T
        left::GenericTree{T}
        right::GenericTree{T}
    end
end

@data ParamDefault{T} begin
    struct A
        x::T
        y::T = zero(T)
    end
end

@testset "keyword constructor of a generic named variant infers its parameter" begin
    @test GenericDefault.A(1.0, 0) isa GenericDefault.Type{Float64}
    @test GenericDefault.A{Float64}(; x=1.0) isa GenericDefault.Type{Float64}
    @test GenericDefault.B(1.0) isa GenericDefault.Type{Float64}
    @test GenericDefault.A(; x=1.0) isa GenericDefault.Type{Float64}
    @test GenericDefault.B(; x=1.0) isa GenericDefault.Type{Float64}
    a = GenericDefault.A(; y=2, x="s")
    @test a isa GenericDefault.Type{String}
    @test (a.x, a.y) == ("s", 2)
    @test_throws UndefKeywordError GenericDefault.A(; y=2)

    # a parameter only in a self-reference is pinned by the other fields
    @test GenericTree.Node(; value=1, left=GenericTree.Leaf(), right=GenericTree.Leaf()) isa
        GenericTree.Type{Int}

    # `T` only appears in a default, so it cannot be inferred
    @test ParamDefault.A{Float64}(; x=1.0).y === 0.0
    @test_throws MethodError ParamDefault.A(; x=1.0)
end

module ShadowedParam
using Moshi.Data: @data
struct T end
@data Box{T} begin
    A(T)
end
end # module

@testset "a type parameter shadows a global of the same name" begin
    @test_broken ShadowedParam.Box.A{Int}(1).:1 === 1
    @test_broken ShadowedParam.Box.A(1) isa ShadowedParam.Box.Type{Int}
end

@data Opt{T} begin
    None()
    Some(T)
end

@testset "singleton of a generic ADT" begin
    x::Opt.Type{Int} = Opt.None()
    @test x isa Opt.Type{Int}
    @test Data.isa_variant(x, Opt.None)
end

@data Other begin
    None()
end

@testset "isa_variant across ADTs" begin
    @test !Data.isa_variant(Other.None(), Opt.None)
    @test !Data.isa_variant(1, Other.None)
end
