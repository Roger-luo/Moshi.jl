@pass function emit_variant_kind(info::EmitInfo)
    jl = JLIfElse()
    for storage in info.storages
        jl[:(data isa $(storage.name))] = quote
            return $(QuoteNode(storage.parent.kind))
        end
    end

    jl.otherwise = quote
        error("unreachable reached")
    end

    return quote
        function $Data.variant_kind(value::Type)
            data = $Base.getfield(value, :data)
            return $(codegen_ast(jl))    
        end
    end
end

@pass function emit_variant_name(info::EmitInfo)
    jl = JLIfElse()
    for storage in info.storages
        jl[:(data isa $(storage.name))] = quote
            return $(QuoteNode(storage.parent.name))
        end
    end

    jl.otherwise = quote
        error("unreachable reached")
    end

    return quote
        function $Data.variant_name(value::Type)
            data = $Base.getfield(value, :data)
            return $(codegen_ast(jl))    
        end
    end
end

@pass function emit_data_type_name(info::EmitInfo)
    return quote
        function $Data.data_type_name(value::Type)
            return $(QuoteNode(info.def.head.name))
        end
    end
end
