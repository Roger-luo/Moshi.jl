struct PatternSyntaxError <: Exception
    msg::String
    source::LineNumberNode
end

PatternSyntaxError(msg::String) = PatternSyntaxError(msg, LineNumberNode(0))

function Base.showerror(io::IO, e::PatternSyntaxError)
    print(io, e.msg)
    e.source.line > 0 || return nothing
    file = e.source.file === nothing ? "none" : e.source.file
    return print(io, "\n  at ", file, ":", e.source.line)
end

# NOTE: this is used at runtime, we want the guarantee of
# zero runtime dependency for match
function x_syntax_error(msg, source)
    return Expr(:block, source, xcall(Base, :error, msg))
end
