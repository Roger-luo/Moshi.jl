struct Unreachable <: Exception end

Base.showerror(io::IO, x::Unreachable) = print(io, "unreachable reached")

struct IllegalDispatch <: Exception end

function Base.showerror(io::IO, x::IllegalDispatch)
    return print(io, "illegal dispatch, expect to be overloaded by @data")
end

