using Test
using Moshi.Data: Data, @data
using Moshi.Derive: @derive

@data Message begin
    Quit
    struct Move
        x::Int
        y::Int
    end

    Write(String)
    ChangeColor(Int, Int, Int)
end

@derive Message[Hash]

type_hash = hash(hash(Message.Type))
@test hash(Message.Quit()) == hash(type_hash, hash(Message.Quit))
@test hash(Message.Move(1, 2)) == hash(2, hash(1, hash(type_hash, hash(Message.Move))))
