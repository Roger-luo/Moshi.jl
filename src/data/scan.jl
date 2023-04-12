struct DataVar
    name::Symbol
end

struct ParametricType
    type
    typevars::Vector{Any}
    unknowns::Vector{Int} # index of typevars that are unknown
end

mutable struct VariantFieldInfo
    expr::Union{Symbol, Expr}
    isbitstype::Bool
    contain_vars::Bool
    guess
end

struct VariantInfo
    parent::Variant
    fields::Vector{VariantFieldInfo}
end

function VariantInfo(def::TypeDef, var::Variant)
    isnothing(var.fields) && return VariantInfo(var, VariantFieldInfo[])
    bit_offset = 0; ptr_index = 0
    info = map(var.fields) do f::Union{Field, NamedField}
        type = guess_type(def, f.type)
        VariantFieldInfo(
            f.type,
            type isa Type ? isbitstype(type) : false,
            type isa Type ? false : true,
            type,
        )
    end
    return VariantInfo(var, info)
end

function guess_type(def::TypeDef, type)
    function find(type::Symbol)
        for tv in def.typevars
            tv.name == type && return tv
        end
        return
    end

    type isa Type && return type

    if type isa Symbol
        if (tv = find(type); !isnothing(tv))
            return DataVar(type)
        elseif isdefined(def.mod, type)
            return getfield(def.mod, type)
        else
            throw(SyntaxError("unknown type: $type"; def.source))
        end
    elseif Meta.isexpr(type, :curly)
        name = type.args[1]
        typevars = type.args[2:end]
        type = guess_type(def, name)
        vars, unknowns = [], Int[]
        for tv in typevars
            tv = guess_type(def, tv)
            (tv isa DataVar || tv isa ParametricType) && push!(unknowns, length(vars) + 1) 
            push!(vars, tv)
        end

        if isempty(unknowns)
            return type{vars...}
        else
            return ParametricType(type, vars, unknowns)
        end
    else
        throw(SyntaxError("invalid type: $type"; def.source))
    end
end

struct EmitSize
    bits::Int
    ptrs::Int
    pad::Int
end

struct EmitGeneratedSize
    bits::Symbol
    ptrs::Symbol
end

function EmitSize(def::TypeDef, variants::Dict{Variant, VariantInfo})
    bits, ptrs = 0, 0
    for (variant, info) in variants
        for field in info.fields::Vector{VariantFieldInfo}
            # NOTE: even the variants do not contain
            # typevars, the adt itself can still have
            # type parameters, and we can still just infer
            # memory layout inside macro, unless a field
            # actually contains typevars
            field.contain_vars && return EmitGeneratedSize(gensym("bits"), gensym("ptrs"))
            if field.isbitstype
                bits += sizeof(field.guess)
            else
                ptrs += 1
            end
        end
    end
    pad = 0
    # consider ptrs as well?
    if bits > 0 && ptrs > 0
        pad = 8 - (bits % 8)
        bits += pad
    end
    return EmitSize(bits, ptrs, pad)
end

struct EmitInfo
    parent::TypeDef
    typename::Symbol
    storage::Symbol
    # nothing inicates layout is inferred
    # afterwards in a generated function
    size::Union{EmitSize, EmitGeneratedSize}
    # empty if require generated function
    #
    # range of bytes in the bits storage
    # is given by offset+1:offset+sizeof(guess)
    #
    # if non-isbitstype, then offset is the index
    # of the pointer in the ptrs storage, start from 1
    offsets::Dict{Variant, Vector{Int}}
    variants::Dict{Variant, VariantInfo}
    variant_type_map::Dict{Symbol, UInt8}
end

function EmitInfo(def::TypeDef)
    typename = Symbol("#", def.name, "#Type")
    storage = Symbol("#", def.name, "#Storage")
    type_map = Dict{Symbol, UInt8}()
    variants = Dict{Variant, VariantInfo}()
    offsets = Dict{Variant, Vector{Int}}()
    length(def.variants) > 256 && throw(SyntaxError("cannot have more than 256 variants", def.source))
    for (idx, variant) in enumerate(def.variants)
        type_map[variant.name] = idx - 1
        variants[variant] = VariantInfo(def, variant)
    end
    size = EmitSize(def, variants)

    if size isa EmitGeneratedSize
        return EmitInfo(def, typename, storage, size, offsets, variants, type_map)
    end

    for (variant, info) in variants
        bit_offset = 0; ptr_index = 1;
        offsets[variant] = map(info.fields) do field
            if field.isbitstype
                ret = bit_offset
                bit_offset += sizeof(field.guess)
            else
                ret = ptr_index
                ptr_index += 1
            end
            ret
        end
    end
    return EmitInfo(def, typename, storage, size, offsets, variants, type_map)
end
