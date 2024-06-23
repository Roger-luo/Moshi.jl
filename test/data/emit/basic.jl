using Test
using Moshi.Data: @data, variant_kind, variant_type, variant_fieldtypes, Named, Anonymous, Singleton

@data Message begin
    Quit
    struct Move
        x::Int
        y::Int
    end

    Write(String)
    ChangeColor(Int, Int, Int)
end

@testset "Message" begin
    x = Message.Quit()
    @test variant_kind(x) == Singleton
    @test_throws ErrorException x.:1
    @test propertynames(x) == ()
    @test sprint(show, x) == "Message.Quit()"
    @test variant_type(x) == Message.Quit
    @test variant_fieldtypes(x) == ()
    @test variant_fieldtypes(Message.Quit) == ()

    x = Message.Move(1, 2)
    @test x.x == 1
    @test x.y == 2
    @test variant_kind(x) == Named
    @test propertynames(x) == (:x, :y)
    @test sprint(show, x) == "Message.Move(x=1, y=2)"
    @test variant_type(x) == Message.Move
    @test variant_fieldtypes(x) == (Int, Int)
    @test variant_fieldtypes(Message.Move) == (Int, Int)

    x = Message.Write("hi")
    @test x.:1 == "hi"
    @test variant_kind(x) == Anonymous
    @test propertynames(x) == (1,)
    @test getproperty(x, 1) == "hi"
    @test sprint(show, x) == "Message.Write(\"hi\")"
    @test variant_type(x) == Message.Write
    @test variant_fieldtypes(x) == (String,)
    @test variant_fieldtypes(Message.Write) == (String,)

    x = Message.ChangeColor(1, 2, 3)
    @test x.:1 == 1
    @test x.:2 == 2
    @test x.:3 == 3
    @test variant_kind(x) == Anonymous
    @test sprint(show, x) == "Message.ChangeColor(1, 2, 3)"
    @test variant_type(x) == Message.ChangeColor
    @test variant_fieldtypes(x) == (Int, Int, Int)
    @test variant_fieldtypes(Message.ChangeColor) == (Int, Int, Int)
end # Message