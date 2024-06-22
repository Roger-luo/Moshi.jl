function show_variant(io::IO, ::MIME"text/plain", x)
    return show_variant(io::IO, x)
end

function show_variant(io::IO, x)
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
    print(io, ")")
end

function variant_name(x)
    throw(IllegalDispatch())
end

function variant_kind(x)
    throw(IllegalDispatch())
end

function data_type_name(x)
    throw(IllegalDispatch())
end

function isa_variant(x, variant::Type)
    throw(IllegalDispatch())
end

"""
Convert a singleton variant with Union{} as type parameters to
a matching singleton variant with the correct type parameters.

!!! note
    `Base.convert(::Type{YourData.Type}, x::YourData.Type{Union{}})` fall back
    to this method so it can be overloaded if necessary. This method fallback to
    a generated method by `@data` by default.
"""
Base.@assume_effects :foldable @inline function convert_singleton_bottom(::Type{T}, x) where T
    return convert_singleton_bottom_generated(T, x)
end

function convert_singleton_bottom_generated(::Type, x)
    throw(IllegalDispatch())
end
