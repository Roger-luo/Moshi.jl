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

    @test Base.Docs.hasdoc(DocTest, :PlainStringFields)
    @test Base.Docs.hasdoc(DocTest, :PlainStringSingleton)
    @test Base.Docs.hasdoc(DocTest, :TripleStringFields)
    @test Base.Docs.hasdoc(DocTest, :TripleStringSingleton)
    @test Base.Docs.hasdoc(DocTest, :ExplicitTripleFields)
    @test Base.Docs.hasdoc(DocTest, :ExplicitTripleSingleton)
    @test Base.Docs.hasdoc(DocTest, :ExplicitMarkdownFields)
    @test Base.Docs.hasdoc(DocTest, :ExplicitMarkdownSingleton)
    @test Base.Docs.hasdoc(DocTest, :NamedWithDoc)
    @test !Base.Docs.hasdoc(DocTest, :NoDocs)
    @test !Base.Docs.hasdoc(DocTest, :NoDocsSingleton)
    @test !Base.Docs.hasdoc(DocTest, :NamedNoDocs)

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

    @test Base.Docs.hasdoc(CustomDocTest, :CustomSingleton)
    @test Base.Docs.hasdoc(CustomDocTest, :CustomFields)
    @test Base.Docs.hasdoc(CustomDocTest, :CustomNamed)
    @test !Base.Docs.hasdoc(CustomDocTest, :NoDoc)

    @test doc_text(CustomDocTest, :CustomSingleton) == "CUSTOM: singleton doc"
    @test doc_text(CustomDocTest, :CustomFields) == "CUSTOM: fields doc"
    @test doc_text(CustomDocTest, :CustomNamed) == "CUSTOM: named doc"
end
