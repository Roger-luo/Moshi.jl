using Test
using Moshi.Data: @data, variants
import Markdown

# Homegrown doc macro: wraps text in a tagged string so we can detect it.
macro customdoc_str(s)
    return "CUSTOM: " * s
end

function doc_text(adtmod::Module, sym::Symbol)
    b = Base.Docs.Binding(adtmod, sym)
    meta = Base.Docs.meta(adtmod)
    haskey(meta, b) || return nothing
    docstr = first(values(meta[b].docs))
    isempty(docstr.text) || return docstr.text[1]
    isnothing(docstr.object) && return nothing
    return string(docstr.object)
end

# `Base.Docs.hasdoc` only exists on Julia >= 1.11; reproduce it on older versions.
@static if VERSION >= v"1.11"
    const hasdoc = Base.Docs.hasdoc
else
    function hasdoc(adtmod::Module, sym::Symbol)
        b = Base.Docs.Binding(adtmod, sym)
        return haskey(Base.Docs.meta(adtmod), b)
    end
end

@testset "variant docstrings" begin
    @data DocTest begin
        "plain string, with fields"
        PlainStringFields(Int, Float32)

        "plain string, no fields"
        PlainStringSingleton

        """
        triple quoted string, with fields
        """
        TripleStringFields(String, Int)

        """
        triple quoted string, no fields
        """
        TripleStringSingleton

        @doc """
        explicit doc triple quoted, with fields
        """
        ExplicitTripleFields(Float32, String)

        @doc """
        explicit doc triple quoted, no fields
        """
        ExplicitTripleSingleton

        @doc Markdown.doc"""
        explicit doc markdown, with fields
        """
        ExplicitMarkdownFields(Float64, Int)

        @doc Markdown.doc"""
        explicit doc markdown, no fields
        """
        ExplicitMarkdownSingleton

        "named struct doc"
        struct NamedWithDoc
            x::Int
            y::Float64
        end

        NoDocs(Int)
        NoDocsSingleton
        struct NamedNoDocs
            z::Int
        end
    end

    @test hasdoc(DocTest, :PlainStringFields)
    @test hasdoc(DocTest, :PlainStringSingleton)
    @test hasdoc(DocTest, :TripleStringFields)
    @test hasdoc(DocTest, :TripleStringSingleton)
    @test hasdoc(DocTest, :ExplicitTripleFields)
    @test hasdoc(DocTest, :ExplicitTripleSingleton)
    @test hasdoc(DocTest, :ExplicitMarkdownFields)
    @test hasdoc(DocTest, :ExplicitMarkdownSingleton)
    @test hasdoc(DocTest, :NamedWithDoc)
    @test !hasdoc(DocTest, :NoDocs)
    @test !hasdoc(DocTest, :NoDocsSingleton)
    @test !hasdoc(DocTest, :NamedNoDocs)

    # Verify doc content is attached to the correct binding for each variant kind.
    @test doc_text(DocTest, :PlainStringFields) == "plain string, with fields"
    @test doc_text(DocTest, :PlainStringSingleton) == "plain string, no fields"
    @test doc_text(DocTest, :NamedWithDoc) == "named struct doc"
    @test occursin("explicit doc markdown, with fields", doc_text(DocTest, :ExplicitMarkdownFields))
    @test occursin("explicit doc markdown, no fields", doc_text(DocTest, :ExplicitMarkdownSingleton))
end

@testset "custom doc macro" begin
    @data CustomDocTest begin
        @doc customdoc"""singleton doc"""
        CustomSingleton

        @doc customdoc"""fields doc"""
        CustomFields(Int, Float32)

        @doc customdoc"""named doc"""
        struct CustomNamed
            x::Int
        end

        NoDoc(Int)
    end

    @test hasdoc(CustomDocTest, :CustomSingleton)
    @test hasdoc(CustomDocTest, :CustomFields)
    @test hasdoc(CustomDocTest, :CustomNamed)
    @test !hasdoc(CustomDocTest, :NoDoc)

    @test doc_text(CustomDocTest, :CustomSingleton) == "CUSTOM: singleton doc"
    @test doc_text(CustomDocTest, :CustomFields) == "CUSTOM: fields doc"
    @test doc_text(CustomDocTest, :CustomNamed) == "CUSTOM: named doc"
end
