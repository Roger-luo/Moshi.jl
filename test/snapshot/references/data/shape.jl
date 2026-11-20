baremodule Shape
using Base: ==
struct var"##Storage#Circle"
    field_1::Float64
end
struct var"##Storage#Rect"
    w::Float64
    h::Float64
end
struct var"typeof(Shape)"
    data::Union{var"##Storage#Circle", var"##Storage#Rect"}
end
const Type = var"typeof(Shape)"
abstract type Variant end
struct Circle <: Variant
    Base.:+(1, 1)
end
struct Rect <: Variant
    Base.:+(1, 1)
end
Base.@constprop :aggressive function Circle(var"1")
        $(Expr(:meta, :inline))
        return Type(var"##Storage#Circle"(Base.convert(Float64, var"1")))
    end
Base.@constprop :aggressive function Rect(w, h)
        $(Expr(:meta, :inline))
        return Type(var"##Storage#Rect"(Base.convert(Float64, w), Base.convert(Float64, h)))
    end
function Rect(; w, h)
    $(Expr(:meta, :inline))
    return Type(var"##Storage#Rect"(Base.convert(Float64, w), Base.convert(Float64, h)))
end
Base.@inline function Base.getproperty(value::Type, name::Symbol)
        data = Base.getfield(value, :data)
        return if data isa var"##Storage#Circle"
                Base.error("anonymous variant has no named fields")
            elseif data isa var"##Storage#Rect"
                if name === :w
                    return Base.getfield(data, name)::Float64
                elseif name === :h
                    return Base.getfield(data, name)::Float64
                else
                    Base.error("unknown field name: $(name)")
                end
            else
                Base.error("unreachable reached")
            end
    end
Base.@inline function Base.getproperty(value::Type, index::Int)
        data = Base.getfield(value, :data)
        return if data isa var"##Storage#Circle"
                if index === 1
                    return Base.getfield(data, index)::Float64
                else
                    Base.error("unknown field index: $(index)")
                end
            elseif data isa var"##Storage#Rect"
                if index === 1
                    return Base.getfield(data, index)::Float64
                elseif index === 2
                    return Base.getfield(data, index)::Float64
                else
                    Base.error("unknown field index: $(index)")
                end
            else
                Base.error("unreachable reached")
            end
    end
Base.@inline Base.@assume_effects(:foldable, function Base.propertynames(value::Type)
            data = Base.getfield(value, :data)
            return if data isa var"##Storage#Circle"
                    return (1,)
                elseif data isa var"##Storage#Rect"
                    return (:w, :h)
                else
                    Base.error("unreachable reached")
                end
        end)
()
()
Base.@inline function Data.variants(::(Type){Type})
        return (Circle, Rect)
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
    return if data isa var"##Storage#Circle"
            return $(QuoteNode(Moshi.Data.Anonymous))
        elseif data isa var"##Storage#Rect"
            return $(QuoteNode(Moshi.Data.Named))
        else
            Base.error("unreachable reached")
        end
end
function Data.variant_kind(::(Type){<:Circle})
    return $(QuoteNode(Moshi.Data.Anonymous))
end
function Data.variant_kind(::(Type){<:Rect})
    return $(QuoteNode(Moshi.Data.Named))
end
Base.@inline function Data.variant_name(::(Type){<:Circle})
        return :Circle
    end
Base.@inline function Data.variant_name(::(Type){<:Rect})
        return :Rect
    end
function Data.variant_name(value::Type)
    data = Base.getfield(value, :data)
    return if data isa var"##Storage#Circle"
            return :Circle
        elseif data isa var"##Storage#Rect"
            return :Rect
        else
            Base.error("unreachable reached")
        end
end
function Data.data_type_name(value::Type)
    return :Shape
end
function Data.data_type_name(value::(Type){<:Type})
    return :Shape
end
function Data.data_type_name(value::(Type){<:Variant})
    return :Shape
end
Base.@constprop :aggressive Base.@assume_effects(:total, function Data.isa_variant(value::Type, variant::(Type){Circle})
            data = Base.getfield(value, :data)
            return data isa var"##Storage#Circle"
        end)
Base.@constprop :aggressive Base.@assume_effects(:total, function Data.isa_variant(value::Type, variant::(Type){Rect})
            data = Base.getfield(value, :data)
            return data isa var"##Storage#Rect"
        end)
Base.@constprop :aggressive Base.@assume_effects(:foldable, function Data.variant_type(value::Type)
            data = Base.getfield(value, :data)
            return if data isa var"##Storage#Circle"
                    return Circle
                elseif data isa var"##Storage#Rect"
                    return Rect
                else
                    Base.error("unreachable reached")
                end
        end)
Base.@inline function Data.variant_storage(value::Type)
        return Base.getfield(value, :data)
    end
Base.@assume_effects :foldable function Data.variant_fieldtypes(value::Type)
        data = Base.getfield(value, :data)
        return if data isa var"##Storage#Circle"
                return (Float64,)
            elseif data isa var"##Storage#Rect"
                return (Float64, Float64)
            else
                Base.error("unreachable reached")
            end
    end
function Data.variant_fieldtypes(::(Type){<:Type})
    return Base.error("cannot obtain fieldnames on data type, unknown variant")
end
Base.@assume_effects :foldable function Data.variant_fieldtypes(::(Type){Circle})
        return (Float64,)
    end
Base.@assume_effects :foldable function Data.variant_fieldtypes(::(Type){Rect})
        return (Float64, Float64)
    end
Base.@inline function Data.variant_fieldnames(::(Type){<:Circle})
        return (1,)
    end
Base.@inline function Data.variant_fieldnames(::(Type){<:Rect})
        return (:w, :h)
    end
Base.@inline function Data.variant_fieldnames(::(Type){<:Type})
        return Base.error("cannot obtain fieldnames on data type, unknown variant")
    end
Base.@inline function Data.variant_nfields(::(Type){<:Circle})
        return $(QuoteNode(1))
    end
Base.@inline function Data.variant_nfields(::(Type){<:Rect})
        return $(QuoteNode(2))
    end
Base.@inline function Data.variant_getfield(value::Type, tag::(Type){Circle}, field::Symbol)
        data = Base.getfield(value, :data)::var"##Storage#Circle"
        return begin
                Base.error("cannot obtain fieldnames on data type, variant type not applicable")
            end
    end
Base.@inline function Data.variant_getfield(value::Type, tag::(Type){Rect}, field::Symbol)
        data = Base.getfield(value, :data)::var"##Storage#Rect"
        return if field === :w
                return Base.getfield(data, :w)::Float64
            elseif field === :h
                return Base.getfield(data, :h)::Float64
            else
                Base.error("field not found")
            end
    end
Base.@inline function Data.variant_getfield(value::Type, tag::(Type){Circle}, field::Int)
        data = (getfield)(value, :data)::var"##Storage#Circle"
        return if field === $(QuoteNode(1))
                return (getfield)(data, $(QuoteNode(1)))::Float64
            else
                Base.error("field not found")
            end
    end
Base.@inline function Data.variant_getfield(value::Type, tag::(Type){Rect}, field::Int)
        data = (getfield)(value, :data)::var"##Storage#Rect"
        return if field === $(QuoteNode(1))
                return (getfield)(data, $(QuoteNode(1)))::Float64
            elseif field === $(QuoteNode(2))
                return (getfield)(data, $(QuoteNode(2)))::Float64
            else
                Base.error("field not found")
            end
    end
nothing
nothing
Data.storage_types(::(Type){Type}) = begin
        Base.ImmutableDict(Base.Pair(Circle, var"##Storage#Circle"), Base.Pair(Rect, var"##Storage#Rect"))
    end
function Data.data_type(::(Type){Circle})
    return Type
end
function Data.data_type(::(Type){Rect})
    return Type
end
public Circle
public Rect
end

Core.@__doc__ Shape
