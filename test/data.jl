using Moshi.Data: TypeDef, Variant, EmitInfo
using ExproniconLite

ex = @expr begin
    Message
    Move(Int, Int)


    struct Port
        name::T
        type::Vector{T} = []
    end
end

def = TypeDef(Main, :(Foo{T} <: Message), ex)
info = EmitInfo(def)

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


ex = @expr begin
    Message
    Move(Int, Int = [])


    struct Port
        name::T
        type::Vector{T} = []
    end
end

def = TypeDef(Main, :(Foo{T, S <: Real} <: Message), ex)


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

def = TypeDef(Main, :(Foo{T <: Real}), ex)

struct Storage{T, N, M}
    bits::NTuple{N, UInt8}
    ptrs::NTuple{M, Any}
end

@generated function Storage{T}(args...) where T
    return :(Storage{T, $(sizeof(T)), 1}(args...))
end

struct Foo{T}
    tag::UInt8
    storage::Storage{T}
end

sizeof(Foo{Float64})
sizeof(Storage{Float64, 8, 1})
sizeof(Float64)
struct Moo
    tag::UInt8
    bits::NTuple{16, UInt8}
    ptrs::NTuple{1, Any}
end
sizeof(Moo)

struct Boo
    tag::UInt8
    storage::Storage{Float64, 16, 1}
end

sizeof(Boo)

function Base.getproperty(f::Foo{T}, name::Symbol) where T
    if f.tag == 1
    elseif f.tag == 2
    elseif f.tag == 3
    end
end

sizeof(Float64)
Foo{Float64}(1, (1, 1, 1, 1, 1, 1, 1, 1), (zero(1), ))

function compute_type(::Type{Foo}, ::Type{T}) where T
    return Foo{T, 1, 1}
end

const Foo{T} = Foo{T, compute_type(Foo, T)...}


def = TypeDef(Main, :Foo, ex)
def.variants[3]

ex = @expr begin
    None
    Some(T)
end
def = TypeDef(Main, :(Option{T}), ex)
def.typevars

struct Option{T}
    tag::UInt8
    parametric::Tuple{T}
end

sizeof(Float64)
data = ntuple(x->zero(UInt8), 8)
