Base.@assume_effects :foldable function unsafe_padded_reinterpret(::Type{T}, x::U) where {T, U}
    @assert isbitstype(T) && isbitstype(U)
    n, m = sizeof(T), sizeof(U)
    if sizeof(U) < sizeof(T)
        payload = (x, ntuple(_ -> zero(UInt8), Val(n-m)), )
    else
        payload = x
    end
    let r = Ref(payload)
        GC.@preserve r begin
            p = pointer_from_objref(r)
            unsafe_load(Ptr{T}(p))
        end
    end
end

@expr begin
    Message
    struct Move
        a::Int
        b::Int
    end

    struct Port
        name::String
        type::Vector{String} = []
    end
end

primitive type FooType 8 end
FooType(x::Int) = Core.bitcast(FooType, UInt8(x))
const Message = FooType(0)
const Move = FooType(1)
const Port = FooType(2)

struct FooStorage
    bits::NTuple{24, UInt8}
    ptrs::NTuple{2, Any}
end

FooStorage(;bits=ntuple(_->zero(UInt8), Val(24)), ptrs=(nothing, nothing)) = FooStorage(bits, ptrs)

struct Foo
    tag::UInt8
    data::FooStorage
end

function (ty::FooType)(args...)
    if ty == Message
        return Foo(0, FooStorage())
    elseif ty == Move
        bits = unsafe_padded_reinterpret(
            NTuple{24, UInt8}, (convert(Int, args[1]), convert(Int, args[2]))
        )
        ptrs = (nothing, nothing, )
        return Foo(1, FooStorage(bits, ptrs))
    elseif ty == Port
        return Foo(2, FooStorage(;ptrs=(
            convert(String, args[1]),
            convert(Vector{String}, args[2]),
        )))
    else
        throw(ArgumentError("invalid tag"))
    end
end

function Base.getproperty(f::Foo, name::Symbol)
    tag = getfield(f, :tag)
    data = getfield(f, :data)::FooStorage
    if tag == 0
        throw(ArgumentError("singleton variant does not have fields"))
    elseif tag == 1
        if name == :a
            return unsafe_padded_reinterpret(Int, data.bits[1:8])::Int
        elseif name == :b
            return unsafe_padded_reinterpret(Int, data.bits[9:16])::Int
        else
            throw(ArgumentError("invalid field name"))
        end
    elseif tag == 2
        if name == :name
            return data.ptrs[1]::String
        elseif name == :type
            return data.ptrs[2]::Vector{String}
        else
            throw(ArgumentError("invalid field name"))
        end
    else
        throw(ArgumentError("invalid tag"))
    end
end

function Base.propertynames(f::Foo)
    tag = getfield(f, :tag)
    if tag == 0
        return ()
    elseif tag == 1
        return (:a, :b)
    elseif tag == 2
        return (:name, :type)
    else
        throw(ArgumentError("invalid tag"))
    end
end

function Base.show(io::IO, f::Foo)
    tag = getfield(f, :tag)
    if tag == 0
        print(io, "Message()")
    elseif tag == 1
        print(io, "Move(")
        print(io, f.a)
        print(io, ", ")
        print(io, f.b)
        print(io, ")")
    elseif tag == 2
        print(io, "Port(")
        print(io, repr(f.name))
        print(io, ", ")
        print(io, repr(f.type))
        print(io, ")")
    else
        throw(ArgumentError("invalid tag"))
    end
end

[Message(), Move(1, 2), Port("a", ["b", "c"])]
sizeof(Foo)
