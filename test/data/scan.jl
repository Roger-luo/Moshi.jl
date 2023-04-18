using ExproniconLite
using Moshi.Data: Data, TypeDef, EmitInfo

abstract type Message end

ex = @expr begin
    Message
    Move(Int, Int)

    struct Port
        name::String
        type::Vector{String} = []
    end
end

def = TypeDef(Main, :(Foo{T} <: Message), ex)
info = EmitInfo(def)
Data.emit_cons(info)
Data.emit(info)

x = Foo{Int}.Move(1, 2)
y = Foo{Int}.Port(name="aaa")
Emit.emit_getproperty(info)

ex = @expr begin
    Message
    Move(Int, T)

    struct Port
        name::T
        type::Vector{String} = []
    end
end

def = TypeDef(Main, :(Foo{T <: Real} <: Message), ex)
info = EmitInfo(def)
Data.emit_cons(info)

Data.emit(info)|>eval
Port = var"#Foo#Variant"{Int}(0x02)
x = Port(1, ["a"])
x.type
getproperty(x, :name)
getproperty(x, 1)
propertynames(x)
Foo{Int}.Move(1, 2)
Foo{Int}.Port(name=1)
propertynames(Foo{Int})
Data.emit_type_propertynames(info)
function foo(x::Foo{Int})
    x.name + 2
end
