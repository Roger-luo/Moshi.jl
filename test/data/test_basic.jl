# @data Foo begin
#     Bar(Int)
#     Baz(Float64)

#     struct Goo
#         x::Int
#         y::Float64
#     end
# end

module Foo

struct StorageBar
    f_1::Int
end

struct StorageBaz
    f_1::Int
end

struct StorageGoo
    f_1::Int
    f_2::Int
end

struct Type
    data::Union{StorageBar,StorageBaz,StorageGoo}
end

struct Variant
    tag::UInt8
end

function (variant::Variant)(args...; kwargs...)
    if variant.tag == 0x00
        return Type(StorageBar(args...))
    elseif variant.tag == 0x01
        return Type(StorageBaz(args...))
    elseif variant.tag == 0x02
        return Type(StorageGoo(args...))
    else
        throw(ArgumentError("invalid tag: $variant.tag"))
    end
end

function Base.getproperty(value::Foo.Type, name::Symbol)
    data = getfield(value, :data)
    return Base.getfield(data, name)
end

function Base.propertynames(value::Foo.Type)
    data = getfield(value, :data)
    return Base.fieldnames(typeof(data))
end

const Bar = Variant(0)
const Baz = Variant(1)
const Goo = Variant(2)

end # Foo



x = Foo.Goo(1, 1.0)
@code_warntype x.f_1
x.f_1
