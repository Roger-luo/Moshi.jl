using Test
using Moshi.Data: @data, variants

import Markdown

# Macros must be defined at top level so they are available when @data lowers its body.

macro two_variants()
    esc(quote
        Foo(Int)
        Bar(String)
    end)
end

macro documented(expr)
    :(@doc "auto doc" $(esc(expr)))
end

@testset "variant docstrings" begin
    @data DocTest begin
        "plain string doc"
        Plain(Int)

        """
        triple quoted doc
        """
        Triple(String)

        Markdown.@doc """
        markdown doc
        """ Named_Variant

        NoDocs(Float64)
    end

    @test Base.Docs.hasdoc(DocTest, :Plain)
    @test Base.Docs.hasdoc(DocTest, :Triple)
    @test Base.Docs.hasdoc(DocTest, :Named_Variant)
    @test !Base.Docs.hasdoc(DocTest, :NoDocs)
end

@testset "macro expanding to multiple variants" begin
    @data MultiMacro begin
        @two_variants()
        Baz
    end

    @test variants(MultiMacro.Type) == (MultiMacro.Foo, MultiMacro.Bar, MultiMacro.Baz)
end

@testset "macro adding a docstring" begin
    @data MacroDoc begin
        @documented Alpha(Int)
        Beta
    end

    @test Base.Docs.hasdoc(MacroDoc, :Alpha)
    @test !Base.Docs.hasdoc(MacroDoc, :Beta)
end
