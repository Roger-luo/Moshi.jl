using Test
using ExproniconLite: @expr, no_default
using Moshi.Data: Variant, Singleton, Named, Anonymous, Field, NamedField, TypeHead, TypeDef

@testset "basic TypeDef" begin
    ex = quote
        """
        Goo
        """
        Goo

        """
        GooBar
        """
        GooBar(Int, Int)

        """
        Baz
        """
        struct Baz
        x::Float64
        y::Float64 = 2.0
        end
    end
    def = TypeDef(Main, :Foo, ex)


    @test def.head == TypeHead(:Foo)
    @test length(def.variants) == 3
    @test def.variants[1].source == ex.args[1]
    @test def.variants[2].source == ex.args[3]
end # TypeDef

@testset "generic TypeDef" begin
    ex = quote
        """
        Goo
        """
        Goo

        """
        GooBar
        """
        GooBar(T, T)

        """
        Baz
        """
        struct Baz
            x::T
            y::T = 2.0
        end
    end
    def = TypeDef(Main, :(Foo{T}), ex)


    @test def.head == TypeHead(:(Foo{T}))
    @test length(def.variants) == 3
    @test def.variants[1].source == ex.args[1]
    @test def.variants[2].source == ex.args[3]
end # TypeDef

@testset "TypeHead" begin
    @test TypeHead(:Foo) == TypeHead(; name=:Foo)
    @test TypeHead(:(Foo{T})) == TypeHead(; name=:Foo, params=[TypeVarExpr(:T)])
    @test TypeHead(:(Foo{T} <: Super{T})) ==
          TypeHead(; name=:Foo, params=[TypeVarExpr(:T)], supertype=:(Super{T}))
    @test TypeHead(:(Foo{T<:Real} <: Super{T})) ==
          TypeHead(; name=:Foo, params=[TypeVarExpr(:T; ub=:(Real))], supertype=:(Super{T}))
    @test TypeHead(:(Foo{T>:Real} <: Super{T})) ==
          TypeHead(; name=:Foo, params=[TypeVarExpr(:T; lb=:(Real))], supertype=:(Super{T}))
end

@testset "Variant(singleton)" begin
    x = Variant(:Foo)
    @test x.kind == Singleton
    @test x.name == :Foo
    @test x.fields == nothing
    @test x.doc == nothing
    @test x.source == nothing

    x = Variant(@expr @doc "Foo" Foo)

    @test x.doc == "Foo"
end

@testset "Variant(Anonymous)" begin
    x = Variant(:(Foo(Int, Float16)))
    @test x.kind == Anonymous
    @test x.name == :Foo
    @test x.fields == [Field(:Int), Field(:Float16)]
    @test x.doc == nothing
    @test x.source == nothing

    x = Variant(@expr @doc "Foo" Foo(Int, Float16))
    @test x.doc == "Foo"

    ex = quote
        """
        Foo
        """
        Foo(Int, Int)
    end
    x = Variant(ex.args[2])
    @test x.doc == """
    Foo
    """
    @test x.source == ex.args[2].args[2]
end # testset


@testset "Variant(Named)" begin
    ex = @expr struct Foo
        x::Int
        y::Int = 2
    end
    x = Variant(ex)

    @test x.kind == Named
    @test x.name === :Foo
    f1 = x.fields[1]
    f2 = x.fields[2]
    @test f1.name === :x
    @test f1.type === :Int
    @test f1.default === no_default
    @test f1.source === ex.args[3].args[1]
end # Variant(Named)
