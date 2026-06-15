using Test
using Moshi.Data: @data, variants
import Markdown

function doc_text(adtmod::Module, sym::Symbol)
    b = Base.Docs.Binding(adtmod, sym)
    meta = Base.Docs.meta(parentmodule(adtmod))
    haskey(meta, b) || return nothing
    return first(values(meta[b].docs)).text[1]
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
end
