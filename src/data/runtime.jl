"""
$DEF

Print the variant to the given IO stream in multiple lines.
"""
@pub function show_variant(io::IO, mime::MIME"text/plain", x)
    return show_variant(io::IO, x)
end

"""
$DEF

Print the variant to the given IO stream in a single line.
"""
@pub function show_variant(io::IO, x)
    print(io, data_type_name(x))
    print(io, ".")
    print(io, variant_name(x))
    type_parameters = typeof(x).parameters
    if !isempty(type_parameters)
        print(io, "{")
        for (i, type_parameter) in enumerate(type_parameters)
            if i > 1
                print(io, ", ")
            end
            print(io, type_parameter)
        end
        print(io, "}")
    end

    print(io, "(")
    if variant_kind(x) == Singleton
    elseif variant_kind(x) == Anonymous
        data = getfield(x, 1)
        for i in 1:nfields(data)
            if i > 1
                print(io, ", ")
            end
            show(io, getfield(data, i))
        end
    else
        for (i, name) in enumerate(propertynames(x))
            if i > 1
                print(io, ", ")
            end

            value = getproperty(x, name)
            print(io, name)
            print(io, "=")
            show(io, value)
        end
    end
    return print(io, ")")
end

"""
$DEF

Check if the given object is a variant of a algebraic data type.
"""
@pub function is_data_type(x)::Bool
    return false
end

"""
$DEF

Return the data type of the given variant type.
"""
@pub function data_type(variant::Type)::Type
    return throw(IllegalDispatch())
end

"""
$DEF

Check if the given object is a variant type.
"""
@pub function is_variant_type(x)::Bool
    return false
end

"""
$DEF

Return a tuple of variants of the given data type.
"""
@pub function variants(x::Type)::Tuple
    throw(IllegalDispatch())
end

"""
$DEF

Return a tuple of variants of the given data type.
"""
@pub function variants(x)
    return variants(typeof(x))
end

"""
$DEF

Return the name of the variant.
"""
@pub function variant_name(x)::Symbol
    throw(IllegalDispatch())
end

"""
$DEF

Return the kind of the variant, can be `Singleton`, `Anonymous`, or `Named`.
"""
@pub function variant_kind(x)::VariantKind
    throw(IllegalDispatch())
end

"""
$DEF

Return the variant type of the given variant.
"""
@pub function variant_type(x)
    throw(IllegalDispatch())
end

"""
$DEF

Return the storage object of the variant.
"""
@pub function variant_storage(value)
    throw(IllegalDispatch())
end

"""
$DEF

Return the number of fields of the variant.
"""
@pub function variant_nfields(value)
    throw(IllegalDispatch())
end

"""
$DEF

Return the field names of the variant.
"""
@pub function variant_fieldnames(value)
    return propertynames(value)
end

"""
$DEF

Return the field types of the variant.
"""
@pub function variant_fieldtypes(type::Type)::Tuple
    throw(
        IllegalDispatch("incomplete type information for $type, missing type parameters?")
    )
end

@pub function variant_fieldtypes(value)
    throw(IllegalDispatch("got $(typeof(type)) for $type"))
end

"""
$DEF

Return the data type name of the given variant.
"""
@pub function data_type_name(x)::Symbol
    throw(IllegalDispatch())
end

"""
$DEF

Check if the given variant is an instance of the given variant type.
"""
@pub function isa_variant(x, variant::Type)::Bool
    throw(IllegalDispatch("got $(typeof(x)) for $variant"))
end

"""
Convert a singleton variant with Union{} as type parameters to
a matching singleton variant with the correct type parameters.

!!! note
    `Base.convert(::Type{YourData.Type}, x::YourData.Type{Union{}})` fall back
    to this method so it can be overloaded if necessary. This method fallback to
    a generated method by `@data` by default.
"""
Base.@assume_effects :foldable @inline function convert_singleton_bottom(
    ::Type{T}, x
) where {T}
    return convert_singleton_bottom_generated(T, x)
end

function convert_singleton_bottom_generated(::Type, x)
    throw(IllegalDispatch())
end

"""
$DEF

Known the variant type `tag`, return the field of the variant by field name or index.

!!! note
    This method is used by the pattern matching system to extract the field of the variant.
    It is not intended to be used directly. Most of cases, you can use the `x.field` syntax
    to extract the field of the variant. However, Julia compiler is not able to infer the
    type of the variant usually, so if you care about performance, you may want to use this
    method in combine with [`variant_storage`](@ref).
"""
@pub function variant_getfield(value, tag::Type, field::Union{Int,Symbol})
    throw(IllegalDispatch())
end

"""
$DEF

Return the storage types of the data type.

!!! note
    This method is used by the pattern matching system to extract the field of the variant.
"""
@pub function storage_types(value::Type)::Base.ImmutableDict{DataType, DataType}
    throw(IllegalDispatch())
end

# HINT
storage_types(mod::Module) = error("got module $mod, do you mean $mod.Type?")

"""
$DEF

Return the storage type of the variant.
"""
@pub function variant_storage_type(tag::Type)::Type
    return storage_types(data_type(tag))[tag]
end
