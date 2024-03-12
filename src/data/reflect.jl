"""
$INTERFACE

Check if given object is a data type or data type instance.
"""
@interface is_data_type(variant_instance_or_type)::Bool = false

"""
$INTERFACE

Get the name of a data type or data type instance.
"""
@interface data_type_name(variant_instance_or_type)::Symbol = invalid_method()

"""
$INTERFACE

Get the module of a data type or data type instance.
"""
@interface data_type_module(variant_instance_or_type)::Module = invalid_method()

"""
$INTERFACE

Return a Tuple of all variant objects of given data type.
"""
@interface variants(type)::Tuple = invalid_method()

"""
$INTERFACE

Get the name of a variant instance or variant type.
"""
@interface variant_name(variant_instance_or_type)::Symbol = invalid_method()

"""
$INTERFACE

Get the [`VariantKind`](@ref) of a given variant instance or variant type.
"""
@interface variant_kind(variant_instance_or_type)::VariantKind = invalid_method()

"""
$INTERFACE

Get the variant type of a given variant instance.
"""
@interface variant_type(variant_instance) = invalid_method()

"""
$INTERFACE

Return the storage object of given variant instance.
"""
@interface variant_storage(variant_instance) = invalid_method()

"""
$INTERFACE

Return the tag of given variant instance.
"""
@interface variant_tag(variant_instance)::UInt8 = invalid_method()

"""
$INTERFACE

Return the field names of given variant instance.
"""
@interface variant_fieldnames(variant_instance)::Tuple = invalid_method()

"""
$INTERFACE

Return the field types of given variant instance.
"""
@interface variant_fieldtypes(variant_instance)::Tuple = invalid_method()

"""
$INTERFACE

Return the number of fields of given variant instance.
"""
@interface variant_nfields(variant_instance)::Int = invalid_method()

"""
$INTERFACE

Check if given variant instance is a singleton.
"""
@interface is_singleton(variant_instance_or_type)::Bool = invalid_method()

"""
$INTERFACE

Get the `idx`-th field name of given variant type.
"""
@interface variant_fieldname(variant_instance, idx::Int)::Symbol =
    variant_fieldnames(variant_instance)[idx]

"""
$INTERFACE

Get the `idx`-th field type of given variant type.
"""
@interface variant_fieldtype(variant_instance, idx::Int)::Symbol =
    variant_fieldtypes(variant_instance)[idx]

"""
$INTERFACE

Get the field of given variant instance by index knowing the variant type.
"""
@interface variant_getfield(variant_instance, ::Val, idx::Int) = invalid_method()

"""
$INTERFACE

Get the field of given variant instance by name knowing the variant type.
"""
@interface variant_getfield(variant_instance, ::Val, name::Symbol) = invalid_method()

"""
$INTERFACE

Check if given object is a variant instance of given variant type.
"""
Base.@constprop :aggressive @interface function isa_variant(instance, variant)
    is_singleton(instance) && return instance === variant
    return variant_type(instance) === variant
end
