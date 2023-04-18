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

ex = @expr begin
    Message
    struct Move
        a::Int
        b::T
    end

    struct Port
        name::Int
        type::String
    end
end

def = TypeDef(Main, :(Foo{T} <: Message), ex)
info = EmitInfo(def)

ex = @expr begin
    Message
    struct Move
        a::T
        b::T
    end

    struct Port
        name::T
        type::String
    end
end

def = TypeDef(Main, :(Foo{T} <: Message), ex)
info = EmitInfo(def)
info.variants[def.variants[2]].fields[2]

struct NoType end
struct Move{T} end
struct Port{T} end

struct FooStorage{T, M, N}
    bits::NTuple{M, UInt8}
    ptrs::NTuple{N, Any}
end

function FooStorage{T}() where {T}
    FooStorage{T, 2 * sizeof(T), 1}(
        unsafe_padded_reinterpret(NTuple{2 * sizeof(T), UInt8}, ()),
        (nothing, )
    )
end

FooStorage{Int}()

function data_sizeof(::Type{Foo{T}}) where {T}
    sizeof(FooStorage{T, 2 * sizeof(T), 1}) + sizeof(Foo{T})
end

primitive type FooType{T} 8 end

@generated function (vt::FooType{T})(args...) where {T}
    M, N = 2 * sizeof(T), 1
    quote
        if Core.bitcast(UInt8, vt) == 0x00
            length(args) == 0 || throw(ArgumentError("invalid number of arguments"))
            Foo{T}(vt, FooStorage{T, $M, $N}(
                unsafe_padded_reinterpret(NTuple{$(M), UInt8}, ()),
                (nothing, )
            ))
        elseif Core.bitcast(UInt8, vt) == 0x01
            length(args) == 2 || throw(ArgumentError("invalid number of arguments"))
            bits = unsafe_padded_reinterpret(
                NTuple{$(M), UInt8}, (convert($T, args[1]), convert($T, args[2]))
            )
            ptrs = (nothing, )
            Foo{$T}(
                vt,
                FooStorage{$(T), $M, $N}(bits, ptrs)
            )
        elseif Core.bitcast(UInt8, vt) == 0x02
            length(args) == 2 || throw(ArgumentError("invalid number of arguments"))
            bits = unsafe_padded_reinterpret(
                NTuple{$(M), UInt8}, (convert($T, args[1]), )
            )
            ptrs = (convert(String, args[2]), )
            Foo{$T}(
                vt,
                FooStorage{$(T), $M, $N}(bits, ptrs)
            )
        else
            throw(ArgumentError("invalid variant tag"))
        end
    end
end

struct Foo{T}
    tag::FooType{T}
    data::FooStorage{T}
end

@generated function Move{T}(a, b) where T
    M, N = 2 * sizeof(T), 1
    return quote
        bits = unsafe_padded_reinterpret(
            NTuple{$(M), UInt8}, (convert($T, a), convert($T, b))
        )
        ptrs = (nothing, )
        Foo{$T}(
            Core.bitcast(FooType{$T}, UInt8(1)),
            FooStorage{$(T), $M, $N}(bits, ptrs)
        )
    end
end

@generated function Port{T}(name, type) where T
    M, N = 2 * sizeof(T), 1
    return quote
        bits = unsafe_padded_reinterpret(
            NTuple{$(M), UInt8}, (convert($T, name), )
        )
        ptrs = (convert(String, type), )
        Foo{$T}(
            Core.bitcast(FooType{$T}, UInt8(2)),
            FooStorage{$(T), $M, $N}(bits, ptrs)
        )
    end
end

const Message = Foo{NoType}(Core.bitcast(FooType{NoType}, UInt8(0)), FooStorage{NoType, 0, 0}((), ()))
Move{UInt32}(1, 1)
Port{UInt32}(1, "hello")
Move(a::T, b::T) where T = Move{T}(a, b)
Port(name::T, type::String) where T = Port{T}(name, type)

@generated function Base.getproperty(f::Foo{T}, name::Symbol) where {T}
    M, N = 2 * sizeof(T), 1
    quote
        tag = getfield(f, :tag)::FooType{$(T)}
        tag = Core.bitcast(UInt8, tag)
        data = getfield(f, :data)::FooStorage{$(T), $M, $N}
        if tag == 0
            throw(ArgumentError("singleton variant does not have fields"))
        elseif tag == 1
            if name == :a
                return unsafe_padded_reinterpret($T, data.bits[1:$(sizeof(T))])::T
            elseif name == :b
                return unsafe_padded_reinterpret($T, data.bits[$(sizeof(T))+1:$(2*sizeof(T))])::T
            else
                throw(ArgumentError("invalid field name"))
            end
        elseif tag == 2
            if name == :name
                return unsafe_padded_reinterpret($T, data.bits[1:$(sizeof(T))])::T
            elseif name == :type
                return data.ptrs[1]::String
            else
                throw(ArgumentError("invalid field name"))
            end
        else
            throw(ArgumentError("invalid tag"))
        end
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

function foo(x::Foo{T}) where T
    tag = getfield(x, :tag)
    if tag == 1
        return x.a + x.b
    elseif tag == 2
        return x.name
    else
        throw(ArgumentError("invalid tag"))
    end
end

function Base.getproperty(t::Type{Foo{T}}, name::Symbol) where {T}
    name in fieldnames(DataType) && return getfield(t, name)
    if name == :Message
        return Core.bitcast(FooType{T}, UInt8(0))
    elseif name == :Move
        return Core.bitcast(FooType{T}, UInt8(1))
    elseif name == :Port
        return Core.bitcast(FooType{T}, UInt8(2))
    else
        throw(ArgumentError("invalid field name"))
    end
end

@code_warntype foo(Move(1, 2))

Foo{Int}.Move(1, 2)
Foo{T}(1)
