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
            print(io, getfield(data, i))
        end
    else
        for (i, name) in enumerate(propertynames(x))
            if i > 1
                print(io, ", ")
            end

            value = getproperty(x, name)
            print(io, name)
            print(io, "=")
            print(io, value)
        end
    end
    print(io, ")")
end

function variant_name(x)
    error("expected to be overloaded by @data")
end

function variant_kind(x)
    error("expected to be overloaded by @data")
end

function data_type_name(x)
    error("expected to be overloaded by @data")
end
