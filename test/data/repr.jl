using Test
using Moshi.Data: TypeDef, TypeHead, scan_type_head, TypeVarExpr

@testset "scan_type_head" begin
    @test scan_type_head(:Foo) == TypeHead(; name=:Foo)
    @test scan_type_head(:(Foo{T})) == TypeHead(; name=:Foo, params=[TypeVarExpr(:T)])
    @test scan_type_head(:(Foo{T} <: Super{T})) ==
          TypeHead(; name=:Foo, params=[TypeVarExpr(:T)], supertype=:(Super{T}))
    @test scan_type_head(:(Foo{T<:Real} <: Super{T})) ==
          TypeHead(; name=:Foo, params=[TypeVarExpr(:T; ub=:(Real))], supertype=:(Super{T}))
    @test scan_type_head(:(Foo{T>:Real} <: Super{T})) ==
          TypeHead(; name=:Foo, params=[TypeVarExpr(:T; lb=:(Real))], supertype=:(Super{T}))
end
