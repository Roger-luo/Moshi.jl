using Test
using Moshi.Data: @data, variants

@testset "variant docstrings" begin
    @data DocTest begin
        "plain string doc"
        Plain(Int)

        """
        triple quoted doc
        """
        Triple(String)

        NoDocs(Float64)
    end

    @test Base.Docs.hasdoc(DocTest, :Plain)
    @test Base.Docs.hasdoc(DocTest, :Triple)
    @test !Base.Docs.hasdoc(DocTest, :NoDocs)
end
