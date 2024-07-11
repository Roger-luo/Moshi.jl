function derive_impl(::Val{:Show}, mod::Module, type::Module) # derive for data type
    return quote
        function $Base.show(io::IO, x::$type.Type)
            return $Data.show_variant(io, x)
        end

        function $Base.show(io::IO, mime::$(MIME"text/plain"), x::$type.Type)
            return $Data.show_variant(io, mime, x)
        end
    end    
end
