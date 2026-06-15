using Test
using Moshi.Data: @data, variants
import Markdown

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

        NoDocs(Int)
        NoDocsSingleton
    end

    @test Base.Docs.hasdoc(DocTest, :PlainStringFields)
    @test Base.Docs.hasdoc(DocTest, :PlainStringSingleton)
    @test Base.Docs.hasdoc(DocTest, :TripleStringFields)
    @test Base.Docs.hasdoc(DocTest, :TripleStringSingleton)
    @test Base.Docs.hasdoc(DocTest, :ExplicitTripleFields)
    @test Base.Docs.hasdoc(DocTest, :ExplicitTripleSingleton)
    @test Base.Docs.hasdoc(DocTest, :ExplicitMarkdownFields)
    @test Base.Docs.hasdoc(DocTest, :ExplicitMarkdownSingleton)
    @test !Base.Docs.hasdoc(DocTest, :NoDocs)
    @test !Base.Docs.hasdoc(DocTest, :NoDocsSingleton)
end
