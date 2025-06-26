@pass function emit_getproperty(info::EmitInfo)
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
                return $Base.getfield(data, name)::$(storage.annotations[i])
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
        $Base.@assume_effects :foldable function $Base.getproperty(
            value::$(info.type_head), name::Symbol
        ) where {$(info.whereparams...)}
            data = $Base.getfield(value, :data)
            return $(codegen_ast(jl))
        end
    end # quote
end

@pass function emit_getproperty_index(info::EmitInfo)
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
                return $Base.getfield(data, index)::$(storage.annotations[i])
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
            $Base.@assume_effects :foldable function $Base.getproperty(
                value::Type, index::Int
            )
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end # quote
    else
        return quote
            $Base.@assume_effects :foldable function $Base.getproperty(
                value::$(info.type_head), index::Int
            ) where {$(info.whereparams...)}
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end # quote
    end
end

@pass function emit_propertynames(info::EmitInfo)
    jl = JLIfElse()
    for storage in info.storages
        if storage.parent.kind == Singleton
            jl[:(data isa $(storage.name))] = quote
                return ()
            end
        elseif storage.parent.kind == Anonymous
            jl[:(data isa $(storage.name))] = quote
                return $(Tuple(1:length(storage.parent.fields)))
            end
        else
            names = [field.name for field in storage.parent.fields]
            jl[:(data isa $(storage.name))] = quote
                return $(Tuple(names))
            end
        end
    end
    jl.otherwise = quote
        $Base.error("unreachable reached")
    end

    return quote
        $Base.@inline $Base.@assume_effects :foldable function $Base.propertynames(
            value::Type
        )
            data = $Base.getfield(value, :data)
            return $(codegen_ast(jl))
        end
    end
end
