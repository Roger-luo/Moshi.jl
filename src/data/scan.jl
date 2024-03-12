struct SizeInfo
    tag::Int
    bits::Int
    ptrs::Int
end

struct Storage
    name::Symbol
    size::SizeInfo
end

mutable struct FieldInfo
    var::Symbol
    type # eval-ed type with self
    expr::Union{Symbol,Expr,Type,SelfType}
    is_bitstype::Bool
    type_guess # eval-ed type with self to be Any
    index::Union{Int,UnitRange{Int},Symbol}
    function FieldInfo(var, type, expr, isbitstype, type_guess)
        return new(var, type, expr, isbitstype, type_guess)
    end
end

struct VariantInfo
    def::Variant
    tag::UInt8
    fields::Vector{FieldInfo}
end

Base.eltype(::Type{VariantInfo}) = FieldInfo
Base.length(info::VariantInfo) = length(info.fields)
function Base.iterate(info::VariantInfo, st::Int=1)
    st > length(info) && return nothing
    return (info.fields[st], st + 1)
end

struct TypeInfo
    name::Symbol
    variant::Symbol
    storage::Storage
end

struct EmitInfo
    def::TypeDef
    type::TypeInfo
    variants::Dict{Variant,VariantInfo}
end

function EmitInfo(def::TypeDef)
    info = Dict{Variant,VariantInfo}()
    for (idx, variant) in enumerate(def.variants)
        info[variant] = VariantInfo(def, variant, idx - 1)
    end

    type = TypeInfo(def, info)
    update_index!(info, type.storage.size)
    return EmitInfo(def, type, info)
end

function Storage(def::TypeDef, size::SizeInfo)
    name = Symbol("#", def.name, "#Storage")
    return Storage(name, size)
end

function TypeInfo(def::TypeDef, info::Dict{Variant,VariantInfo})
    size = SizeInfo(def, info)
    storage = Storage(def, size)
    return TypeInfo(:Type, Symbol("#", def.name, "#Variant"), storage)
end

function SizeInfo(def::TypeDef, info::Dict{Variant,VariantInfo})
    bits = count_bytes(isbitstype, f -> sizeof(f.type_guess), info)
    ptrs = count_bytes(!isbitstype, f -> 1, info)
    tag = paded_tag_nbits(bits, ptrs)
    return SizeInfo(tag, bits, ptrs)
end

function VariantInfo(def::TypeDef, variant::Variant, tag::Int)
    fields = Vector{FieldInfo}(undef, length(variant.fields))
    variant.kind === Singleton && return VariantInfo(variant, tag, fields)

    for (kth_field::Int, f::Union{Field,NamedField}) in enumerate(variant.fields)
        guess = guess_type(def, f.type)
        var = if f isa NamedField
            Symbol("##", variant.name, "#", f.name, "#", kth_field)
        else
            Symbol("##", variant.name, "#", kth_field)
        end
        get_expr = Symbol("##", variant.name, "#get#", kth_field)
        fields[kth_field] = FieldInfo(
            var, materialize_self(def, f.type), f.type, isbitstype(guess), guess
        )
    end
    return VariantInfo(variant, tag, fields)
end

function paded_tag_nbits(bits_byte::Int, ptrs_byte::Int)
    total_byte = bits_byte + ptrs_byte
    return if total_byte <= 1
        1
    elseif total_byte <= 2
        2
    elseif total_byte <= 4
        4
    else
        sizeof(UInt)
    end
end

function count_bytes(::typeof(isbitstype), map, info::Dict{Variant,VariantInfo})
    maximum(values(info); init=0) do info::VariantInfo
        values = Iterators.filter(f -> f.is_bitstype, info.fields)
        mapfoldl(+, values; init=0) do f::FieldInfo
            map(f)
        end
    end
end

function count_bytes(
    ::ComposedFunction{typeof(!),typeof(isbitstype)}, map, info::Dict{Variant,VariantInfo}
)
    maximum(values(info); init=0) do info::VariantInfo
        values = Iterators.filter(f -> !f.is_bitstype, info.fields)
        mapfoldl(+, values; init=0) do f::FieldInfo
            map(f)
        end
    end
end

function update_index!(info::Dict{Variant,VariantInfo}, size::SizeInfo)
    for (_, vinfo::VariantInfo) in info
        start = 0
        ptr = 1
        for f::FieldInfo in vinfo
            if f.is_bitstype
                stop = start + sizeof(f.type_guess)
                f.index = (start + 1):stop
                start = stop
            else
                f.index = ptr
                ptr += 1
            end
        end
    end
    return info
end

function typevars_to_expr(def::TypeDef)
    map(def.typevars) do tv::TypeVar
        if !isnothing(tv.lower) && !isnothing(tv.upper)
            :($(tv.lower) <: $(tv.name) <: $(tv.upper))
        elseif isnothing(tv.lower) && !isnothing(tv.upper)
            :($(tv.name) <: $(tv.upper))
        elseif !isnothing(tv.lower) && isnothing(tv.upper)
            :($(tv.lower) <: $(tv.name))
        else
            tv.name::Symbol
        end
    end
end
