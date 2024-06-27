struct PatternSyntaxError <: Exception
    msg::String
    source::LineNumberNode
end

PatternSyntaxError(msg::String) = PatternSyntaxError(msg, LineNumberNode(0))

Base.showerror(io::IO, e::PatternSyntaxError) = print(io, e.msg)
