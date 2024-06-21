using Test
using Moshi.Data: Data, TypeDef, Variant, EmitInfo, emit

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

@testset "concrete" begin
    def = TypeDef(Main, :(Foo), ex)
    info = EmitInfo(def)
    @test isempty(info.params)
    @test isempty(info.whereparams)
    @test info.type_head === :Type
    @test info.storages[1].name === Symbol("##Storage#Goo")
    @test info.storages[1].head === Symbol("##Storage#Goo")
    @test info.storages[1].variant_head === :Goo
    @test isempty(info.storages[1].types)
    @test info.storages[2].types == [Int, Int]
end

@testset "parametric" begin
    def = TypeDef(Main, :(Foo{T<:Real}), ex)
    info = EmitInfo(def)
    @test info.params == [:T]
    @test info.whereparams[1] == :(T <: $Real)
    @test info.type_head == :(Type{T})
    @test info.storages[1].name == Symbol("##Storage#Goo")
    @test info.storages[1].head == :($(Symbol("##Storage#Goo")){T})
    @test info.storages[1].variant_head == :(Goo{T})
    @test isempty(info.storages[1].types)
    @test info.storages[2].types == [Int, Int]
end
