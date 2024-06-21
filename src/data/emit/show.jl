@pass function emit_show(info::EmitInfo)
    return quote
        function $Base.show(io::IO, x::Type)
            $Data.show_variant(io, x)
        end

        function $Base.show(io::IO, mime::$(MIME"text/plain"), x::Type)
            $Data.show_variant(io, mime, x)
        end
    end
end
