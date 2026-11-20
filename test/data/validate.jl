using Test
using Moshi.Data: @data, TypeDef

"The error `f()` throws, unwrapped from `LoadError`; `nothing` when it does not throw."
function thrown(f)
    try
        f()
    catch err
        return err isa LoadError ? err.error : err
    end
    return nothing
end

"The `ArgumentError` scanning a `@data` body made of `stmts` throws."
function duplicate_error(stmts...; name=:Dup)
    return thrown(() -> TypeDef(@__MODULE__, false, name, Expr(:block, stmts...)))
end

@testset "duplicate variant names" begin
    @testset "of every variant kind" begin
        kinds = [:(A()), :(A(Int)), :(struct A
            x::Int
        end)]
        for first in kinds, second in kinds
            err = duplicate_error(first, second)
            @test err isa ArgumentError
            @test startswith(err.msg, "duplicate variant `A` in `Dup`")
        end
    end

    @testset "with the deprecated bare singleton" begin
        err = @test_logs (:warn, r"deprecated") match_mode = :any duplicate_error(
            :A, :(A())
        )
        @test err isa ArgumentError
    end

    @testset "reports the second definition" begin
        err = duplicate_error(
            LineNumberNode(1, :dup),
            :(A()),
            LineNumberNode(2, :dup),
            :(B()),
            LineNumberNode(3, :dup),
            :(A(Int)),
            LineNumberNode(4, :dup),
            :(A(Float64)),
        )
        @test err.msg == "duplicate variant `A` in `Dup` (near dup:3)"
    end

    @testset "without a line number" begin
        @test duplicate_error(:(A()), :(A(Int))).msg == "duplicate variant `A` in `Dup`"
    end

    @testset "inside @doc and nested blocks" begin
        doc = Expr(:macrocall, Symbol("@doc"), LineNumberNode(5, :dup), "doc", :(A(Int)))
        @test duplicate_error(:(A()), doc).msg ==
            "duplicate variant `A` in `Dup` (near dup:5)"
        nested = Expr(:block, LineNumberNode(6, :dup), :(A(Int)))
        @test duplicate_error(:(A()), nested).msg ==
            "duplicate variant `A` in `Dup` (near dup:6)"
    end

    @testset "names the type without its parameters" begin
        err = duplicate_error(:(A(T)), :(A()); name=:(Dup{T} <: Integer))
        @test err.msg == "duplicate variant `A` in `Dup`"
    end

    @testset "distinct names stay accepted" begin
        def = TypeDef(@__MODULE__, false, :Distinct, quote
            A()
            a()
            B(Int)
        end)
        @test [v.name for v in def.variants] == [:A, :a, :B]
    end

    @testset "through @data, before anything is defined" begin
        for ex in (:(@data DupPlain begin
            A()
            A(Int)
        end), :(@data DupGeneric{T} begin
            A(T)
            A()
        end), :(@data mutable DupMutable begin
            struct A
                x::Int
            end
            A(Int)
        end))
            err = thrown(() -> Core.eval(@__MODULE__, ex))
            @test err isa ArgumentError
            @test occursin("duplicate variant `A`", err.msg)
            @test occursin(r"validate\.jl:\d+", err.msg)
        end
        @test !isdefined(@__MODULE__, :DupPlain)
        @test !isdefined(@__MODULE__, :DupGeneric)
        @test !isdefined(@__MODULE__, :DupMutable)
    end
end
