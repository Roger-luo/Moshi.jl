using Test
using Moshi.Data: @data

module ExportVariants
using Moshi.Data: @data

@data Shape begin
    export Circle, Square

    Circle(Float64)
    Square(Float64)
    Triangle(Float64, Float64)
end

# `using` the generated ADT module should bring only the exported
# constructors into scope.
module Consumer
    using ..Shape
end # module Consumer
end # module ExportVariants

# an ADT without an `export` statement keeps the default (public-only) behavior.
@data NoExport begin
    A()
    B(Int)
end

@testset "export selected variants" begin
    Shape = ExportVariants.Shape

    @test Base.isexported(Shape, :Circle)
    @test Base.isexported(Shape, :Square)
    @test !Base.isexported(Shape, :Triangle)

    @static if VERSION >= v"1.11-"
        # `export` implies public; non-exported variants stay public.
        @test Base.ispublic(Shape, :Circle)
        @test Base.ispublic(Shape, :Square)
        @test Base.ispublic(Shape, :Triangle)
    end

    # only exported constructors are visible in a module that `using`s the ADT.
    @test ExportVariants.Consumer.Circle === Shape.Circle
    @test ExportVariants.Consumer.Square === Shape.Square
    @test !isdefined(ExportVariants.Consumer, :Triangle)
end

@testset "no export statement stays public-only" begin
    @test !Base.isexported(NoExport, :A)
    @test !Base.isexported(NoExport, :B)
    @static if VERSION >= v"1.11-"
        @test Base.ispublic(NoExport, :A)
        @test Base.ispublic(NoExport, :B)
    end
end

@testset "export validation" begin
    bad = :(@data BadExport begin
        export Nope

        Foo()
    end)
    err = try
        macroexpand(@__MODULE__, bad)
        nothing
    catch e
        e
    end
    @test err isa Exception
    @test occursin("not a variant", sprint(showerror, err))
end
