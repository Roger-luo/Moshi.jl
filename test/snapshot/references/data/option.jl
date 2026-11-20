baremodule Option
using Base: ==
struct var"##Storage#None"{T}
end
struct var"##Storage#Some"{T}
    field_1::T
end
struct var"typeof(Option)"{T}
    data::Union{var"##Storage#None"{T}, var"##Storage#Some"{T}}
end
const Type{T} = var"typeof(Option)"{T}
abstract type Variant end
struct None{T} <: Variant
    Base.:+(1, 1)
end
struct Some{T} <: Variant
    Base.:+(1, 1)
end
Base.@constprop :aggressive function None{T}() where T
        $(Expr(:meta, :inline))
        return Type{T}(var"##Storage#None"{T}())
    end
Base.@constprop :aggressive function Some{T}(var"1") where T
        $(Expr(:meta, :inline))
        return Type{T}(var"##Storage#Some"{T}(Base.convert(T, var"1")))
    end
function Some(var"1"::T) where T
    $(Expr(:meta, :inline))
    return Type{T}(var"##Storage#Some"{T}(var"1"))
end
function None()
    $(Expr(:meta, :inline))
    return Type{Union{}}(var"##Storage#None"{Union{}}())
end
Base.@inline function Base.getproperty(value::Type{T}, name::Symbol) where T
        data = Base.getfield(value, :data)
        return if data isa var"##Storage#None"
                Base.error("singleton variant has no fields")
            elseif data isa var"##Storage#Some"
                Base.error("anonymous variant has no named fields")
            else
                Base.error("unreachable reached")
            end
    end
Base.@inline function Base.getproperty(value::Type{T}, index::Int) where T
        data = Base.getfield(value, :data)
        return if data isa var"##Storage#None"
                Base.error("singleton variant has no fields")
            elseif data isa var"##Storage#Some"
                if index === 1
                    return Base.getfield(data, index)::T
                else
                    Base.error("unknown field index: $(index)")
                end
            else
                Base.error("unreachable reached")
            end
    end
Base.@inline Base.@assume_effects(:foldable, function Base.propertynames(value::Type)
            data = Base.getfield(value, :data)
            return if data isa var"##Storage#None"
                    return ()
                elseif data isa var"##Storage#Some"
                    return (1,)
                else
                    Base.error("unreachable reached")
                end
        end)
()
()
Base.@inline function Data.variants(::(Type){<:Type})
        return (None, Some)
    end
Base.@inline function Data.variants(::(Type){Type{T}}) where T
        return (None{T}, Some{T})
    end
Base.@inline function Data.is_data_type(value::(Type){<:Type})
        return true
    end
Base.@inline function Data.is_variant_type(value::(Type){<:Variant})
        return true
    end
Base.@inline function Data.is_data_type(value::Type)
        return true
    end
function Data.variant_kind(value::Type)
    data = Base.getfield(value, :data)
    return if data isa var"##Storage#None"
            return $(QuoteNode(Moshi.Data.Singleton))
        elseif data isa var"##Storage#Some"
            return $(QuoteNode(Moshi.Data.Anonymous))
        else
            Base.error("unreachable reached")
        end
end
function Data.variant_kind(::(Type){<:None})
    return $(QuoteNode(Moshi.Data.Singleton))
end
function Data.variant_kind(::(Type){<:Some})
    return $(QuoteNode(Moshi.Data.Anonymous))
end
Base.@inline function Data.variant_name(::(Type){<:None})
        return :None
    end
Base.@inline function Data.variant_name(::(Type){<:Some})
        return :Some
    end
function Data.variant_name(value::Type)
    data = Base.getfield(value, :data)
    return if data isa var"##Storage#None"
            return :None
        elseif data isa var"##Storage#Some"
            return :Some
        else
            Base.error("unreachable reached")
        end
end
function Data.data_type_name(value::Type)
    return :Option
end
function Data.data_type_name(value::(Type){<:Type})
    return :Option
end
function Data.data_type_name(value::(Type){<:Variant})
    return :Option
end
Base.@constprop :aggressive function Data.isa_variant(value::Type, variant::(Type){None})
        data = Base.getfield(value, :data)
        return data isa var"##Storage#None"
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type{T}, variant::(Type){None{T}}) where T
        data = Base.getfield(value, :data)
        return data isa var"##Storage#None"
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type{T}, variant::(Type){None{T_1}}) where {T, T_1}
        return false
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type{T}, variant::(Type){<:None}) where T
        data = Base.getfield(value, :data)
        return data isa var"##Storage#None" && None{T} <: variant
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type, variant::(Type){Some})
        data = Base.getfield(value, :data)
        return data isa var"##Storage#Some"
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type{T}, variant::(Type){Some{T}}) where T
        data = Base.getfield(value, :data)
        return data isa var"##Storage#Some"
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type{T}, variant::(Type){Some{T_1}}) where {T, T_1}
        return false
    end
Base.@constprop :aggressive function Data.isa_variant(value::Type{T}, variant::(Type){<:Some}) where T
        data = Base.getfield(value, :data)
        return data isa var"##Storage#Some" && Some{T} <: variant
    end
Base.@constprop :aggressive Base.@assume_effects(:foldable, function Data.variant_type(value::Type{T}) where T
            data = Base.getfield(value, :data)
            return if data isa var"##Storage#None"
                    return None{T}
                elseif data isa var"##Storage#Some"
                    return Some{T}
                else
                    Base.error("unreachable reached")
                end
        end)
Base.@inline function Data.variant_storage(value::Type)
        return Base.getfield(value, :data)
    end
Base.@assume_effects :foldable function Data.variant_fieldtypes(value::Type{T}) where T
        data = Base.getfield(value, :data)
        return if data isa var"##Storage#None"
                return ()
            elseif data isa var"##Storage#Some"
                return (T,)
            else
                Base.error("unreachable reached")
            end
    end
function Data.variant_fieldtypes(::(Type){<:Type})
    return Base.error("cannot obtain fieldnames on data type, unknown variant")
end
Base.@assume_effects :foldable function Data.variant_fieldtypes(::(Type){None{T}}) where T
        return ()
    end
Base.@assume_effects :foldable function Data.variant_fieldtypes(::(Type){None})
        T = Any
        return ()
    end
Base.@assume_effects :foldable function Data.variant_fieldtypes(::(Type){Some{T}}) where T
        return (T,)
    end
Base.@assume_effects :foldable function Data.variant_fieldtypes(::(Type){Some})
        T = Any
        return (T,)
    end
Base.@inline function Data.variant_fieldnames(::(Type){<:None})
        return ()
    end
Base.@inline function Data.variant_fieldnames(::(Type){<:Some})
        return (1,)
    end
Base.@inline function Data.variant_fieldnames(::(Type){<:Type})
        return Base.error("cannot obtain fieldnames on data type, unknown variant")
    end
Base.@inline function Data.variant_nfields(::(Type){<:None})
        return $(QuoteNode(0))
    end
Base.@inline function Data.variant_nfields(::(Type){<:Some})
        return $(QuoteNode(1))
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){None}, field::Symbol) where T
        data = Base.getfield(value, :data)::var"##Storage#None"{T}
        return begin
                Base.error("cannot obtain fieldnames on data type, variant type not applicable")
            end
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){Some}, field::Symbol) where T
        data = Base.getfield(value, :data)::var"##Storage#Some"{T}
        return begin
                Base.error("cannot obtain fieldnames on data type, variant type not applicable")
            end
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){None}, field::Int) where T
        data = (getfield)(value, :data)::var"##Storage#None"{T}
        return begin
                Base.error("cannot obtain fieldnames on data type, variant type not applicable")
            end
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){Some}, field::Int) where T
        data = (getfield)(value, :data)::var"##Storage#Some"{T}
        return if field === $(QuoteNode(1))
                return (getfield)(data, $(QuoteNode(1)))::T
            else
                Base.error("field not found")
            end
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){None{T}}, field::Union{Int, Symbol}) where T
        return Data.variant_getfield(value, None, field)
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){<:None}, field::Union{Int, Symbol}) where T
        None{T} <: tag || Base.error("type parameters of given variant type do not match input value")
        return Data.variant_getfield(value, None, field)
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){Some{T}}, field::Union{Int, Symbol}) where T
        return Data.variant_getfield(value, Some, field)
    end
Base.@inline function Data.variant_getfield(value::Type{T}, tag::(Type){<:Some}, field::Union{Int, Symbol}) where T
        Some{T} <: tag || Base.error("type parameters of given variant type do not match input value")
        return Data.variant_getfield(value, Some, field)
    end
function Data.storage_types(::(Type){<:Type})
    return (Base.ImmutableDict)(Base.Pair(None, var"##Storage#None"), Base.Pair(Some, var"##Storage#Some"))
end
function Data.storage_types(::(Type){Type{T}}) where T
    return Base.ImmutableDict(Base.Pair(None, var"##Storage#None"{T}), Base.Pair(Some, var"##Storage#Some"{T}))
end
function Data.data_type(::(Type){None{T}}) where T
    return Type{T}
end
function Data.data_type(::(Type){<:None})
    return Type
end
function Data.data_type(::(Type){Some{T}}) where T
    return Type{T}
end
function Data.data_type(::(Type){<:Some})
    return Type
end
Base.@assume_effects :foldable Base.@inline(function Data.convert(::(Type){Type{T}}, value::Type{Union{}}) where T
            return Data.convert_singleton_bottom(Type{T}, value)
        end)
Base.@assume_effects :foldable Base.@inline(function Data.convert_singleton_bottom_generated(::(Type){Type{T}}, value::Type{Union{}}) where T
            data = getfield(value, :data)
            return if data isa var"##Storage#None"
                    return Type{T}(var"##Storage#None"{T}())
                else
                    Base.error("unexpected type conversion from $(Data.variant_name(value)) to Option.Type{T}")
                end
        end)
public None
public Some
end

Core.@__doc__ Option
