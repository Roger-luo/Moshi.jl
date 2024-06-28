"""
$INTERFACE

Print the variant to the given IO stream in multiple lines.
"""
@interface function show_variant(io::IO, mime::MIME"text/plain", x)
    return show_variant(io::IO, x)
end

"""
$INTERFACE

Print the variant to the given IO stream in a single line.
"""
@interface function show_variant(io::IO, x)
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
$INTERFACE

Check if the given object is a variant of a algebraic data type.
"""
@interface function is_data_type(x)::Bool
    return false
end

"""
$INTERFACE

Return a tuple of variants of the given data type.
"""
@interface function variants(x::Type)::Tuple
    throw(IllegalDispatch())
end

"""
$INTERFACE

Return a tuple of variants of the given data type.
"""
function variants(x)
    return variants(typeof(x))
end

"""
$INTERFACE

Return the name of the variant.
"""
@interface function variant_name(x)::Symbol
    throw(IllegalDispatch())
end

"""
$INTERFACE

Return the kind of the variant, can be `Singleton`, `Anonymous`, or `Named`.
"""
@interface function variant_kind(x)::VariantKind
    throw(IllegalDispatch())
end

"""
$INTERFACE

Return the variant type of the given variant.
"""
@interface function variant_type(x)
    throw(IllegalDispatch())
end

"""
$INTERFACE

Return the storage object of the variant.
"""
@interface function variant_storage(value)
    throw(IllegalDispatch())
end

"""
$INTERFACE

Return the number of fields of the variant.
"""
@interface function variant_nfields(value)
    throw(IllegalDispatch())
end

"""
$INTERFACE

Return the field names of the variant.
"""
@interface function variant_fieldnames(value)
    return propertynames(value)
end

"""
$INTERFACE

Return the field types of the variant.
"""
@interface function variant_fieldtypes(type::Type)::Tuple
    throw(IllegalDispatch("incomplete type information for $type, missing type parameters?"))
end

@interface function variant_fieldtypes(value)
    throw(IllegalDispatch("got $(typeof(type)) for $type"))
end

"""
$INTERFACE

Return the data type name of the given variant.
"""
@interface function data_type_name(x)::Symbol
    throw(IllegalDispatch())
end

"""
$INTERFACE

Check if the given variant is an instance of the given variant type.
"""
@interface function isa_variant(x, variant::Type)::Bool
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
