using Test
using Moshi.Data: @data

sym_union(T) = Union{T,Symbol}

@data CallType begin
    struct AxisAngle
        n::sym_union(Vector{Float64}) = [1.0, 0.0, 0.0]
        angle::sym_union(Float64) = 0.0
    end
    struct Quaternion
        Q::sym_union(Vector{Float64}) = [1.0, 0.0, 0.0, 0.0]
    end
end

@testset "CallType: function-call field types" begin
    a = CallType.AxisAngle()
    @test a.n == [1.0, 0.0, 0.0]
    @test a.angle == 0.0

    a2 = CallType.AxisAngle(n=:unset, angle=:unset)
    @test a2.n === :unset
    @test a2.angle === :unset

    q = CallType.Quaternion()
    @test q.Q == [1.0, 0.0, 0.0, 0.0]
end

wrap(T) = Vector{T}

@data CallTypeParam{T} begin
    struct Wrapped
        v::wrap(T)
    end
end

@testset "CallTypeParam{T}: TypeVar inferred through call" begin
    w = CallTypeParam.Wrapped([1.0, 2.0])
    @test w.v == [1.0, 2.0]
end

nested_union(T) = Union{T,Nothing}

@data NestedCall begin
    struct Inner
        x::sym_union(nested_union(Int)) = 0
    end
end

@testset "NestedCall: nested function calls in type position" begin
    i = NestedCall.Inner()
    @test i.x == 0
    i2 = NestedCall.Inner(x=nothing)
    @test i2.x === nothing
    i3 = NestedCall.Inner(x=:tag)
    @test i3.x === :tag
end
