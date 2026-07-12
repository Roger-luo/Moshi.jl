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

function derive_impl(::Val{:Show}, mod::Module, type::Union{DataType,UnionAll}) # plain struct
    type_name = string(nameof(type))
    body = Expr(:block, :($Base.print(io, $type_name, "(")))
    for (i, name) in enumerate(fieldnames(type))
        i > 1 && push!(body.args, :($Base.print(io, ", ")))
        push!(body.args, :($Base.show(io, $Base.getfield(x, $(QuoteNode(name))))))
    end
    push!(body.args, :($Base.print(io, ")")))

    return quote
        function $Base.show(io::IO, x::$type)
            $body
            return nothing
        end
    end
end
