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

@pass function emit_isa_variant(info::EmitInfo)
    if isempty(info.params) # non generic
        return expr_map(info.storages) do storage::StorageInfo
            return quote
                $Base.@assume_effects :total function $Data.isa_variant(
                    value::Type, variant::$Type{$(storage.parent.name)}
                )
                    data = $Base.getfield(value, :data)
                    return data isa $(storage.name)
                end
            end
        end
    else
        others = [gensym(param) for param in info.params]
        return expr_map(info.storages) do storage::StorageInfo
            return quote
                # just checking the tag value
                function $Data.isa_variant(
                    value::Type, variant::$Type{$(storage.parent.name)}
                )
                    data = $Base.getfield(value, :data)
                    return data isa $(storage.name)
                end

                # type params match, check tag value
                function $Data.isa_variant(
                    value::$(info.type_head), variant::$Type{$(storage.variant_head)}
                ) where {$(info.whereparams...)}
                    data = $Base.getfield(value, :data)
                    return data isa $(storage.name)
                end

                # type params mismatch
                function $Data.isa_variant(
                    value::$(info.type_head),
                    variant::$Type{$(storage.parent.name){$(others...)}},
                ) where {$(info.whereparams...), $(others...)}
                    return false
                end
            end
        end
    end
end
