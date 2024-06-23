@pass function emit_is_data_type(info::EmitInfo)
    return quote
        $Base.@inline function $Data.is_data_type(value::Type)
            return true
        end
    end
end

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
                $Base.@constprop :aggressive $Base.@assume_effects :total function $Data.isa_variant(
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
                $Base.@constprop :aggressive function $Data.isa_variant(
                    value::Type, variant::$Type{$(storage.parent.name)}
                )
                    data = $Base.getfield(value, :data)
                    return data isa $(storage.name)
                end

                # type params match, check tag value
                $Base.@constprop :aggressive function $Data.isa_variant(
                    value::$(info.type_head), variant::$Type{$(storage.variant_head)}
                ) where {$(info.whereparams...)}
                    data = $Base.getfield(value, :data)
                    return data isa $(storage.name)
                end

                # type params mismatch
                $Base.@constprop :aggressive function $Data.isa_variant(
                    value::$(info.type_head),
                    variant::$Type{$(storage.parent.name){$(others...)}},
                ) where {$(info.whereparams...),$(others...)}
                    return false
                end
            end
        end
    end
end

@pass function emit_variant_type(info::EmitInfo)
    jl = JLIfElse()
    for storage in info.storages
        jl[:(data isa $(storage.name))] = quote
            return $(storage.variant_head)
        end
    end
    jl.otherwise = quote
        error("unreachable reached")
    end

    return if isempty(info.params)
        quote
            $Base.@constprop :aggressive $Base.@assume_effects :foldable function $Data.variant_type(
                value::$(info.type_head)
            )
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end
    else
        quote
            $Base.@constprop :aggressive $Base.@assume_effects :foldable function $Data.variant_type(
                value::$(info.type_head)
            ) where {$(info.whereparams...)}
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end
    end
end

@pass function emit_reflect_variant_storage(info::EmitInfo)
    return quote
        $Base.@inline function $Data.variant_storage(value::Type)
            return $Base.getfield(value, :data)
        end
    end
end

@pass function emit_variant_fieldtypes(info::EmitInfo)
    jl = JLIfElse()
    for storage in info.storages
        jl[:(data isa $(storage.name))] = quote
            return $(xtuple(storage.annotations...))
        end
    end
    jl.otherwise = quote
        error("unreachable reached")
    end

    if isempty(info.params)
        return quote
            $Base.@assume_effects :foldable function $Data.variant_fieldtypes(value::$(info.type_head))
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end
    else
        return quote
            $Base.@assume_effects :foldable function $Data.variant_fieldtypes(value::$(info.type_head)) where {$(info.whereparams...)}
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end
        end
    end
end
