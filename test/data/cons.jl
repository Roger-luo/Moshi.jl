using Test
using ExproniconLite: @expr, no_default
using Moshi.Data:
    Variant, Singleton, Named, Anonymous, Field, NamedField, TypeHead, TypeVarExpr, TypeDef

@testset "basic TypeDef" begin
    ex = quote
        """
        Goo
        """
        Goo()

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
    def = TypeDef(Main, false, :Foo, ex)

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
        Goo()

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
    def = TypeDef(Main, false, :(Foo{T}), ex)

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
    # explicit singleton form `Foo()` is the canonical spelling
    x = Variant(:(Foo()))
    @test x.kind == Singleton
    @test x.name == :Foo
    @test x.fields == nothing
    @test x.doc == nothing
    @test x.source == nothing

    def = TypeDef(Main, false, :TestDoc, quote
        @doc "Foo" Foo()
    end)
    @test def.variants[1].kind == Singleton
    @test def.variants[1].doc == "Foo"
end

@testset "Variant(singleton) bare form is deprecated" begin
    # The bare identifier form still parses to a Singleton, but is deprecated
    # in favour of the explicit `Foo()` spelling. `--depwarn=error` escalates
    # the deprecation to a throw, so only assert the warning when not enabled.
    if Base.JLOptions().depwarn != 2
        x = @test_deprecated r"deprecated" Variant(:Foo)
        @test x.kind == Singleton
        @test x.name == :Foo
        @test x.fields === nothing
    end
end

@testset "Variant(Anonymous)" begin
    x = Variant(:(Foo(Int, Float16)))
    @test x.kind == Anonymous
    @test x.name == :Foo
    @test x.fields == [Field(:Int), Field(:Float16)]
    @test x.doc == nothing
    @test x.source == nothing

    def = TypeDef(Main, false, :TestDoc, quote
        @doc "Foo" Foo(Int, Float16)
    end)
    @test def.variants[1].doc == "Foo"

    ex = quote
        """
        Foo
        """
        Foo(Int, Int)
    end
    def = TypeDef(Main, false, :TestDoc, ex)
    x = def.variants[1]
    @test x.doc == """
    Foo
    """
    @test x.source == ex.args[2].args[2]
end # testset

@testset "Variant(Named)" begin
    ex = @expr struct Foo
        x::Int
        y::Int = 2
        const z::Int
    end
    x = Variant(ex)

    @test x.kind == Named
    @test x.name === :Foo
    f1 = x.fields[1]
    f2 = x.fields[2]
    f3 = x.fields[3]
    @test f1.name === :x
    @test f1.type === :Int
    @test f1.default === no_default
    @test f1.source === ex.args[3].args[1]
    @test f3.isconst

    def = TypeDef(Main, false, :TestDocNamed, quote
        @doc "Baz doc" struct Baz
            x::Float64
        end
    end)
    @test def.variants[1].doc == "Baz doc"
end # Variant(Named)

@testset "_is_doc_macro GlobalRef form" begin
    # GlobalRef(Core, :@doc) is an alternative head form _is_doc_macro must handle
    expr = Expr(
        :macrocall,
        GlobalRef(Core, Symbol("@doc")),
        LineNumberNode(1, :none),
        "CoreDoc",
        :Foo,
    )
    def = TypeDef(Main, false, :TestCoreDoc, Expr(:block, expr))
    @test length(def.variants) == 1
    @test def.variants[1].name == :Foo
    @test def.variants[1].doc == "CoreDoc"
end

@testset "@doc on block raises error" begin
    # @doc applied to a begin...end block must error rather than silently assign
    # the same doc to every variant inside.
    @test_throws ArgumentError TypeDef(Main, false, :TestDocBlock, quote
        @doc "shared doc" begin
            Foo
            Bar(Int)
        end
    end)
end

@testset "non-@doc macrocall is rejected" begin
    # A macrocall whose head is not `@doc` is not a doc wrapper: _is_doc_macro
    # returns false and the macrocall falls through to Variant, which rejects it.
    expr = Expr(:macrocall, Symbol("@foo"), LineNumberNode(1, :none), :Bar)
    @test_throws ArgumentError TypeDef(Main, false, :TestNonDocMacro, Expr(:block, expr))
end

@testset "nested block without doc is flattened" begin
    # A nested begin...end block (such as one produced by macro expansion) is
    # recursed into, tracking line numbers and skipping generated `nothing` entries.
    inner = Expr(:block, LineNumberNode(7, :none), :(Foo()), nothing, :(Bar(Int)))
    def = TypeDef(Main, false, :TestNestedBlock, Expr(:block, inner))
    @test length(def.variants) == 2
    @test def.variants[1].name === :Foo
    @test def.variants[2].name === :Bar
end
