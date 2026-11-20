begin
    function Base.show(io::IO, x::Shape.Type)
        return Data.show_variant(io, x)
    end
    function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, x::Shape.Type)
        return Data.show_variant(io, mime, x)
    end
end
