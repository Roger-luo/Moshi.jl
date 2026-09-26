using Test
using Moshi.Data: @data
using Moshi.Match: @match

@data Shape begin
    Circle(Float64)
    Rect(Float64, Float64)
end

struct Box
    inner::Any
end

guarded_variant(s) = @match s begin
    Shape.Rect(w, h) && if w == h
    end => w
    Shape.Rect(w, h) => w * h
    Shape.Circle(r) => r
end

guarded_struct(x) = @match x begin
    Box(Box(v)) && if v isa Int
    end => v
    Box(v) => v
    _ => nothing
end

@testset "guarded pattern variables are never maybe-undefined" begin
    @test guarded_variant(Shape.Rect(2.0, 2.0)) == 2.0
    @test guarded_variant(Shape.Rect(2.0, 3.0)) == 6.0
    @test guarded_variant(Shape.Circle(1.0)) == 1.0
    @test guarded_struct(Box(Box(1))) == 1
    @test guarded_struct(Box(Box("s"))) == Box("s")
    @test guarded_struct(Box(2)) == 2
    @test guarded_struct(3) === nothing
    # A `begin ... end` wrapped around part of the match condition makes Julia merge the
    # pattern variables through a possibly-`#undef` phi, which shows up as an undef check
    # in typed IR (and as a JET "may be undefined" report at every use).
    for (f, T) in ((guarded_variant, Shape.Type), (guarded_struct, Any))
        ir = string(first(only(code_typed(f, (T,)))))
        @test !occursin("throw_undef_if_not", ir)
    end
end
