@pass function emit_setproperty(info::EmitInfo)
    if !info.def.ismutable
        return :()
    end
    jl = JLIfElse()
    for storage in info.storages
        if isnothing(storage.parent.fields)
            jl[:(data isa $(storage.name))] = quote
                $Base.error("singleton variant has no fields")
            end
            continue
        end

        if storage.parent.kind == Anonymous
            jl[:(data isa $(storage.name))] = quote
                $Base.error("anonymous variant has no named fields")
            end
            continue
        end

        variant_fields = JLIfElse()
        for (i, field) in enumerate(storage.parent.fields)
            variant_fields[:(name === $(QuoteNode(field.name)))] = quote
                return $Base.setfield!(data, name, new_value)::$(storage.annotations[i])
            end
        end
        variant_fields.otherwise = quote
            $Base.error("unknown field name: $name")
        end

        jl[:(data isa $(storage.name))] = codegen_ast(variant_fields)
    end
    jl.otherwise = quote
        $Base.error("unreachable reached")
    end

    return quote
        $Base.@inline function $Base.setproperty!(
            value::$(info.type_head), name::Symbol, new_value,
        ) where {$(info.whereparams...)}
            data = $Base.getfield(value, :data)
            return $(codegen_ast(jl))
        end
    end # quote
end

@pass function emit_setproperty_index(info::EmitInfo)
    if !info.def.ismutable
        return :()
    end
    jl = JLIfElse()
    for storage in info.storages
        if isnothing(storage.parent.fields)
            jl[:(data isa $(storage.name))] = quote
                $Base.error("singleton variant has no fields")
            end
            continue
        end

        variant_fields = JLIfElse()
        for (i, field) in enumerate(storage.parent.fields)
            variant_fields[:(index === $i)] = quote
                return $Base.setfield!(data, index, new_value)::$(storage.annotations[i])
            end
        end
        variant_fields.otherwise = quote
            $Base.error("unknown field index: $index")
        end

        jl[:(data isa $(storage.name))] = codegen_ast(variant_fields)
    end
    jl.otherwise = quote
        $Base.error("unreachable reached")
    end

    if isempty(info.params)
        return quote
            $Base.@inline function $Base.setproperty!(
                value::Type, index::Int, new_value
            )
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end # quote
    else
        return quote
            $Base.@inline function $Base.setproperty!(
                value::$(info.type_head), index::Int, new_value
            ) where {$(info.whereparams...)}
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end # quote
    end
end
