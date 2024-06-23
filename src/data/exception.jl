struct Unreachable <: Exception end

Base.showerror(io::IO, x::Unreachable) = print(io, "unreachable reached")

Base.@kwdef struct IllegalDispatch <: Exception
    msg::String = ""
end

function Base.showerror(io::IO, x::IllegalDispatch)
    return print(io, "illegal dispatch, expect to be overloaded by @data: $(x.msg)")
end
