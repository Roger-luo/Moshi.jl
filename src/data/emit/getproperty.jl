@pass function emit_getproperty(info::EmitInfo)
    jl = JLIfElse()
    for storage in info.storages
        variant_fields = JLIfElse()
        for (i, field) in enumerate(storage.parent.fields)
            variant_fields[:(name === $(QuoteNode(field.name)))] = quote
                return $Base.getfield(data, name)::$(storage.types[i])
            end
        end
        variant_fields.otherwise = quote
            error("unknown field name: $name")
        end

        jl[:(data isa $(storage.name))] = codegen_ast(variant_fields)
    end
    jl.otherwise = quote
        error("unreachable reached")
    end

    return quote
        $Base.@assume_effects :total function $Base.getproperty(value::Type, name::Symbol)
            data = $Base.getfield(value, :data)
            $(codegen_ast(jl))
        end
    end # quote
end

@pass function emit_propertynames(info::EmitInfo)
    return expr_map(info.storages) do storage
        quote
            $Base.@inline function $Base.propertynames(value::Type)
                data = $Base.getfield(value, :data)
                return $Base.propertynames(data)
            end
        end # quote
    end
end
