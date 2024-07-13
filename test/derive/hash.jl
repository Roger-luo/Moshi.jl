using Test
using Moshi.Data: Data, @data
using Moshi.Derive: @derive, Hash

@data Message begin
    Quit
    struct Move
        x::Int
        y::Int
        cache::Hash.Cache = Hash.Cache()
    end

    Write(String)
    ChangeColor(Int, Int, Int)
end

Data.variant_fieldtypes(Message.Move)
Data.variant_fieldnames(Message.Move)
@derive Message[Hash]

type_hash = hash(hash(Message.Type))
@test hash(Message.Quit()) == hash(type_hash, hash(Message.Quit))
x = Message.Move(x=1, y=2)
@test hash(x) == hash(2, hash(1, hash(type_hash, hash(Message.Move))))
@test x.cache[] == hash(x)
