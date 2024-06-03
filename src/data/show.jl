function Base.show(io::IO, head::TypeHead)
    print(io, head.name)
    if !isempty(head.params)
        print(io, "{")
        print(io, head.params[1])
        for param in head.params[2:end]
            print(io, ", ", param)
        end
        print(io, "}")
    end
    if head.supertype !== nothing
        print(io, " <: ", head.supertype)
    end
end
