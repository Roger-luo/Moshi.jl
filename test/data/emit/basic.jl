using Test
using Moshi.Data:
    @data,
    is_data_type,
    is_variant_type,
    variants,
    variant_kind,
    variant_type,
    variant_storage,
    variant_nfields,
    variant_fieldnames,
    variant_fieldtypes,
    variant_getfield,
    data_type_name,
    isa_variant,
    Named,
    Anonymous,
    Singleton

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
    @test variants(Message.Type) ==
        (Message.Quit, Message.Move, Message.Write, Message.ChangeColor)

    @testset "Quit" begin
        x = Message.Quit()
        @test variants(x) ==
            (Message.Quit, Message.Move, Message.Write, Message.ChangeColor)
        @test is_data_type(x)
        @test is_variant_type(Message.Quit)
        @test isa_variant(Message.Quit(), Message.Quit)
        @test !isa_variant(Message.Quit(), Message.Move)
        @test variant_kind(x) == Singleton
        @test variant_kind(Message.Quit) == Singleton
        @test_throws ErrorException x.:1
        @test propertynames(x) == ()
        @test sprint(show, x) == "Message.Quit()"
        @test variant_type(x) == Message.Quit
        @test variant_fieldtypes(x) == ()
        @test variant_fieldtypes(Message.Quit) == ()
        @test variant_fieldnames(Message.Quit) == ()
        @test_throws ErrorException variant_getfield(Message.Quit(), Message.Quit, 1)
    end # Quit

    @testset "Move" begin
        x = Message.Move(1, 2)
        @test x.x == 1
        @test x.y == 2
        @test is_data_type(x)
        @test is_variant_type(Message.Move)
        @test variant_kind(x) == Named
        @test variant_kind(Message.Move) == Named
        @test propertynames(x) == (:x, :y)
        @test sprint(show, x) == "Message.Move(x=1, y=2)"
        @test variant_type(x) == Message.Move
        @test variant_fieldtypes(x) == (Int, Int)
        @test variant_fieldtypes(Message.Move) == (Int, Int)
        @test variant_fieldnames(Message.Move) == (:x, :y)
        @test variant_getfield(x, Message.Move, 1) == 1
        @test variant_getfield(x, Message.Move, 2) == 2
        @test variant_getfield(x, Message.Move, :x) == 1
        @test variant_getfield(x, Message.Move, :y) == 2
    end # Move

    @testset "Write" begin
        x = Message.Write("hi")
        @test x.:1 == "hi"
        @test is_data_type(x)
        @test is_variant_type(Message.Write)
        @test variant_kind(x) == Anonymous
        @test variant_kind(Message.Write) == Anonymous
        @test propertynames(x) == (1,)
        @test getproperty(x, 1) == "hi"
        @test sprint(show, x) == "Message.Write(\"hi\")"
        @test variant_type(x) == Message.Write
        @test variant_fieldtypes(x) == (String,)
        @test variant_fieldtypes(Message.Write) == (String,)
        @test variant_fieldnames(Message.Write) == (1,)
        @test variant_getfield(x, Message.Write, 1) == "hi"
    end # Write

    @testset "ChangeColor" begin
        x = Message.ChangeColor(1, 2, 3)
        @test x.:1 == 1
        @test x.:2 == 2
        @test x.:3 == 3
        @test is_data_type(x)
        @test is_variant_type(Message.ChangeColor)
        @test variant_kind(x) == Anonymous
        @test variant_kind(Message.ChangeColor) == Anonymous
        @test sprint(show, x) == "Message.ChangeColor(1, 2, 3)"
        @test variant_type(x) == Message.ChangeColor
        @test variant_fieldtypes(x) == (Int, Int, Int)
        @test variant_fieldtypes(Message.ChangeColor) == (Int, Int, Int)
        @test variant_fieldnames(Message.ChangeColor) == (1, 2, 3)
        @test variant_getfield(x, Message.ChangeColor, 1) == 1
        @test variant_getfield(x, Message.ChangeColor, 2) == 2
        @test variant_getfield(x, Message.ChangeColor, 3) == 3
    end

    @test data_type_name(Message.Type) === :Message
    @test data_type_name(Message.Quit) === :Message
    @test data_type_name(Message.Quit()) === :Message

    @test_throws ErrorException variant_fieldtypes(Message.Type)
    @test_throws ErrorException variant_fieldnames(Message.Type)

    @test variant_nfields(Message.Quit) == 0
    @test variant_nfields(Message.Move) == 2
    @test variant_nfields(Message.Write) == 1
    @test variant_nfields(Message.ChangeColor) == 3
end # Message
