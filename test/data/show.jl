using Test
using ExproniconLite: @expr, no_default
using Moshi.Data: Variant, Singleton, Named, Anonymous, Field, NamedField, TypeHead, TypeDef
import Markdown

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

def = TypeDef(Main, false, :Foo, ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, false, :(Foo{T}), ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, false, :(Foo{T} <: SuperType), ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, true, :Foo, ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, true, :(Foo{T}), ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, true, :(Foo{T} <: SuperType), ex)
show(devnull, MIME("text/plain"), def)

function show_variant(def, i)
    buf = IOBuffer()
    show(IOContext(buf, :indent => 4), MIME("text/plain"), def.variants[i])
    return String(take!(buf))
end

@testset "docstring rendering" begin
    string_def = TypeDef(Main, false, :ShowDocTest, quote
        "plain string doc"
        PlainSingleton

        "plain string doc"
        PlainFields(Int, Float32)

        @doc Markdown.doc"""
        markdown doc
        """
        MarkdownSingleton

        @doc Markdown.doc"""
        markdown doc
        """
        MarkdownFields(Int, Float32)
    end)

    @test contains(show_variant(string_def, 1), "plain string doc")
    @test contains(show_variant(string_def, 2), "plain string doc")

    md3 = show_variant(string_def, 3)
    @test contains(md3, "markdown doc")
    @test !contains(md3, "@doc_str")

    md4 = show_variant(string_def, 4)
    @test contains(md4, "markdown doc")
    @test !contains(md4, "@doc_str")

    # outer @data type show includes all variant docs
    buf = IOBuffer()
    show(buf, MIME("text/plain"), string_def)
    out = String(take!(buf))
    @test contains(out, "plain string doc")
    @test contains(out, "markdown doc")
    @test !contains(out, "@doc_str")
end

@testset "non-string doc renders via show_unquoted" begin
    # When a variant's doc is neither a plain string nor a doc-string macrocall,
    # doc_string returns nothing and the raw expression is shown unquoted.
    mc = Expr(:macrocall, Symbol("@doc"), LineNumberNode(1, :none), :somevar, :Foo)
    def = TypeDef(Main, false, :ShowRawDoc, Expr(:block, mc))
    @test def.variants[1].doc === :somevar
    @test contains(show_variant(def, 1), "somevar")
end
