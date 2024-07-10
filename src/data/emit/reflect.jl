module Reflection

using ..Data: @pass, Data, EmitInfo, StorageInfo, Singleton, Anonymous, Named
using ExproniconLite: JLIfElse, xtuple, expr_map, codegen_ast

@pass function emit_variants(info::EmitInfo)
    if isempty(info.params)
        return quote
            $Base.@inline function $Data.variants(::$Type{Type})
                return $(xtuple([storage.variant_head for storage in info.storages]...))
            end
        end
    else
        return quote
            $Base.@inline function $Data.variants(::$Type{<:Type})
                return $(xtuple([storage.parent.name for storage in info.storages]...))
            end

            $Base.@inline function $Data.variants(
                ::$Type{$(info.type_head)}
            ) where {$(info.whereparams...)}
                return $(xtuple([storage.variant_head for storage in info.storages]...))
            end
        end
    end # if
end

@pass function emit_is_data_type(info::EmitInfo)
    return quote
        $Base.@inline function $Data.is_data_type(value::$Type{<:Type})
            return true
        end

        $Base.@inline function $Data.is_data_type(value::$Type{<:Variant})
            return true
        end

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

    on_type = expr_map(info.storages) do storage
        quote
            function $Data.variant_kind(::$Type{<:$(storage.parent.name)})
                return $(QuoteNode(storage.parent.kind))
            end
        end
    end

    return quote
        function $Data.variant_kind(value::Type)
            data = $Base.getfield(value, :data)
            return $(codegen_ast(jl))
        end

        $on_type
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

        function $Data.data_type_name(value::$Type{<:Type})
            return $(QuoteNode(info.def.head.name))
        end

        function $Data.data_type_name(value::$Type{<:Variant})
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

@pass function emit_variant_storage(info::EmitInfo)
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

    unknown_variant = quote
        function $Data.variant_fieldtypes(::$Type{<:Type})
            return $Base.error("cannot obtain fieldnames on data type, unknown variant")
        end
    end

    if isempty(info.params)
        return quote
            $Base.@assume_effects :foldable function $Data.variant_fieldtypes(
                value::$(info.type_head)
            )
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end

            $unknown_variant

            $(expr_map(x -> emit_variant_fieldtypes_each_storage(info, x), info.storages))
        end
    else
        return quote
            $Base.@assume_effects :foldable function $Data.variant_fieldtypes(
                value::$(info.type_head)
            ) where {$(info.whereparams...)}
                data = $Base.getfield(value, :data)
                return $(codegen_ast(jl))
            end

            $unknown_variant

            $(expr_map(x -> emit_variant_fieldtypes_each_storage(info, x), info.storages))
        end
    end
end # emit_variant_fieldtypes

function emit_variant_fieldtypes_each_storage(info::EmitInfo, storage::StorageInfo)
    if isempty(info.params)
        return quote
            $Base.@assume_effects :foldable function $Data.variant_fieldtypes(
                ::$Type{$(storage.variant_head)}
            )
                return $(xtuple(storage.annotations...))
            end
        end
    else
        return quote
            $Base.@assume_effects :foldable function $Data.variant_fieldtypes(
                ::$Type{$(storage.variant_head)}
            ) where {$(info.whereparams...)}
                return $(xtuple(storage.annotations...))
            end
        end
    end
end

@pass function emit_variant_fieldnames(info::EmitInfo)
    main = expr_map(info.storages) do storage
        fieldnames = if storage.parent.kind == Singleton
            ()
        elseif storage.parent.kind == Anonymous
            Tuple(1:length(storage.parent.fields))
        else
            xtuple([QuoteNode(field.name) for field in storage.parent.fields]...)
        end

        return quote
            $Base.@inline function $Data.variant_fieldnames(::$Type{<:$(storage.parent.name)})
                return $(fieldnames)
            end
        end
    end

    return quote
        $main

        $Base.@inline function $Data.variant_fieldnames(::$Type{<:Type})
            return $Base.error("cannot obtain fieldnames on data type, unknown variant")
        end
    end
end # emit_variant_fieldnames

@pass function emit_variant_nfields(info::EmitInfo)
    expr_map(info.storages) do storage
        nfields = isnothing(storage.parent.fields) ? 0 : length(storage.parent.fields)
        return quote
            $Base.@inline function $Data.variant_nfields(::$Type{<:$(storage.parent.name)})
                return $(QuoteNode(nfields))
            end
        end
    end
end

@pass function emit_variant_getfield(info::EmitInfo)
    err = quote
        $Base.error("cannot obtain fieldnames on data type, variant type not applicable")
    end
    otherwise = quote
        $Base.error("field not found")
    end

    named = expr_map(info.storages) do storage
        body = if storage.parent.kind == Named
            jl = JLIfElse()
            for (idx, field) in enumerate(storage.parent.fields)
                jl[:(field === $(QuoteNode(field.name)))] = quote
                    return $Base.getfield(
                        data, $(QuoteNode(field.name))
                    )::$(storage.annotations[idx])
                end
            end
            jl.otherwise = otherwise
            codegen_ast(jl)
        else
            err
        end

        return quote
            $Base.@inline function $Data.variant_getfield(
                value::$(info.type_head),
                tag::$Type{$(storage.parent.name)},
                field::Symbol,
            ) where {$(info.whereparams...)}
                data = $Base.getfield(value, :data)::$(storage.head)
                $body
            end
        end
    end

    numbered = expr_map(info.storages) do storage
        body = if storage.parent.kind == Named || storage.parent.kind == Anonymous
            jl = JLIfElse()
            for (idx, field) in enumerate(storage.parent.fields)
                jl[:(field === $(QuoteNode(idx)))] = quote
                    return $(Base.getfield)(
                        data, $(QuoteNode(idx))
                    )::$(storage.annotations[idx])
                end
            end
            jl.otherwise = otherwise
            codegen_ast(jl)
        else
            err
        end

        return quote
            $Base.@inline function $Data.variant_getfield(
                value::$(info.type_head),
                tag::$Type{$(storage.parent.name)},
                field::Int,
            ) where {$(info.whereparams...)}
                data = $(Base.getfield)(value, :data)::$(storage.head)
                $body
            end
        end
    end

    generic = expr_map(info.storages) do storage
        if isempty(info.params)
            nothing
        else
            quote
                $Base.@inline function $Data.variant_getfield(
                    value::$(info.type_head),
                    tag::$Type{$(storage.variant_head)},
                    field::Union{Int,Symbol},
                ) where {$(info.whereparams...)}
                    return $Data.variant_getfield(value, $(storage.parent.name), field)
                end

                $Base.@inline function $Data.variant_getfield(
                    value::$(info.type_head),
                    tag::$Type{<:$(storage.parent.name)},
                    field::Union{Int,Symbol},
                ) where {$(info.whereparams...)}
                    $Base.error("type parameters of given variant type do not match input value")
                end
            end
        end
    end # storage

    return quote
        $named

        $numbered

        $generic
    end
end

end # module
