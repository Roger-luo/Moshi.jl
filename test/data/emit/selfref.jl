using Test
using Moshi.Data: @data, TypeDef, guess_self_as_any, variant_getfield
using Moshi.Derive: @derive

@data Arith begin
    Num(Int)
    Add(Arith, Arith.Type)
    Sub(Arith, Arith)
end

@testset "selfref" begin
    x = Arith.Add(Arith.Num(1), Arith.Num(1))
    @test Base.return_types(getproperty, Tuple{Arith.Type,Int})[1] == Union{Int,Arith.Type}
    @test variant_getfield(x, Arith.Add, 1) == Arith.Num(1)
end # selfref

@data SelfRef{T} begin
    Ref(SelfRef{T})
    Val(T)
end

@derive SelfRef[Eq]

@testset "selfref{T}" begin
    x = SelfRef.Ref(SelfRef.Val(1))
    @test Base.return_types(getproperty, Tuple{SelfRef.Type{Int},Int})[1] ==
        Union{Int,SelfRef.Type{Int}}

    x = SelfRef.Ref(SelfRef.Val(1))
    y = SelfRef.Ref(SelfRef.Val(1))
    @test x == y
end # selfref{T}

# Issue #33: the ADT name in a default value should refer to `<Name>.Type`, just
# like everywhere else in the `@data` block. `SExpr[]` must not resolve to the
# generated module (which would error with `getindex(::Module)`).
@data SExpr begin
    struct Add
        arguments::Vector{SExpr} = SExpr[]
    end
end

# explicit `.Type` form is accepted and equivalent
@data SExprExplicit begin
    struct Add
        arguments::Vector{SExprExplicit} = SExprExplicit.Type[]
    end
end

@data SExprP{T} begin
    struct Add
        arguments::Vector{SExprP{T}} = SExprP{T}[]
    end
end

@testset "issue #33: self-ref default values" begin
    x = SExpr.Add()
    @test x.arguments isa Vector{SExpr.Type}
    @test isempty(x.arguments)

    y = SExprExplicit.Add()
    @test y.arguments isa Vector{SExprExplicit.Type}
    @test isempty(y.arguments)

    p = SExprP.Add{Int}()
    @test p.arguments isa Vector{SExprP.Type{Int}}
    @test isempty(p.arguments)
end # issue #33
