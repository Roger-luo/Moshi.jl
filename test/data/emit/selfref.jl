using Test
using Moshi.Data: @data, TypeDef, guess_self_as_any
using Moshi.Derive: @derive

@data Arith begin
    Num(Int)
    Add(Arith, Arith.Type)
    Sub(Arith, Arith) 
end

@testset "selfref" begin
    x = Arith.Add(Arith.Num(1), Arith.Num(1))
    @test Base.return_types(getproperty, Tuple{Arith.Type, Int})[1] == Union{Int, Arith.Type}
end # selfref

@data SelfRef{T} begin
    Ref(SelfRef{T})
    Val(T)
end

@derive SelfRef[Eq]

@testset "selfref{T}" begin
    x = SelfRef.Ref(SelfRef.Val(1))
    @test Base.return_types(getproperty, Tuple{SelfRef.Type{Int}, Int})[1] == Union{Int, SelfRef.Type{Int}}

    x = SelfRef.Ref(SelfRef.Val(1))
    y = SelfRef.Ref(SelfRef.Val(1))
    @test x == y
end # selfref{T}
