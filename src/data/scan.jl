struct TypeSize
    tag_byte::Int
    bits_byte::Int
    ptrs_byte::Int
end

struct GeneratedTypeSize
    tag_byte::Symbol
    bits_byte::Symbol
    ptrs_byte::Symbol
end

const Size_t = Union{TypeSize, GeneratedTypeSize}

struct Storage{Size <: Size_t}
    name::Symbol
    type::Union{Symbol, Expr} # with bounds but without size
    cons::Union{Symbol, Expr} # without bounds or size
    full_type::Union{Symbol, Expr} # with bounds & size
    full_cons::Union{Symbol, Expr} # without bounds but with size
    size::Size
end

struct TypeName
    name::Symbol
    full::Union{Symbol, Expr} # type with params
    cons::Union{Symbol, Expr} # type without bounds
end

function TypeName(name, vars::Vector, bounded::Vector)
    full = if isempty(vars)
        name
    else
        :($(name){$(bounded...)})
    end
    cons = if isempty(vars)
        name
    else
        :($(name){$(vars...)})
    end
    return TypeName(name, full, cons)
end

struct TypeInfo{Size <: Union{TypeSize, GeneratedTypeSize}}
    name::TypeName
    variant::TypeName
    vars::Vector{Symbol}
    bounded_vars::Vector{<:Union{Symbol, Expr}}
    storage::Storage{Size}
end

mutable struct FieldInfo
    var::Symbol
    get_expr::Symbol # not used if concrete
    expr::Union{Symbol, Expr}
    is_bitstype::Bool
    is_concrete::Bool
    guess
    index::Union{Int, UnitRange{Int}, Symbol}
    FieldInfo(var, get_expr, expr, isbitstype, is_concrete, guess) =
        new(var, get_expr, expr, isbitstype, is_concrete, guess)
end

struct VariantInfo
    def::Variant
    tag::UInt8
    is_concrete::Bool
    fields::Vector{FieldInfo}
end

Base.eltype(::Type{VariantInfo}) = FieldInfo
Base.length(info::VariantInfo) = length(info.fields)
function Base.iterate(info::VariantInfo, st::Int = 1)
    st > length(info) && return nothing
    return (info.fields[st], st + 1)
end

struct EmitInfo{Size <: Size_t}
    def::TypeDef
    type::TypeInfo{Size}
    variants::Dict{Variant, VariantInfo}
end

function EmitInfo(def::TypeDef)
    info = Dict{Variant, VariantInfo}()
    for (idx, variant) in enumerate(def.variants)
        info[variant] = VariantInfo(def, variant, idx - 1)
    end

    type = TypeInfo(def, info)
    update_index!(info, type.storage.size)
    return EmitInfo(def, type, info)
end

function Storage(def::TypeDef, size::TypeSize, vars, bounded_vars)
    name = Symbol("#", def.name, "#Storage")
    return Storage(name, name, name, name, name, size)
end

function Storage(def::TypeDef, size::GeneratedTypeSize, vars, bounded_vars)
    name = Symbol("#", def.name, "#Storage")
    type = Expr(:curly, name, bounded_vars...)
    full_type = Expr(
        :curly, name, bounded_vars...,
        size.tag_byte,
        size.bits_byte,
        size.ptrs_byte
    )
    cons = Expr(:curly, name, vars...)

    # this is only used inside generated function
    # thus we need to insert the size in generated
    # expression
    full_cons = Expr(
        :curly, name, vars...,
        Expr(:$, size.tag_byte),
        Expr(:$, size.bits_byte),
        Expr(:$, size.ptrs_byte),
    )
    return Storage(name, type, cons, full_type, full_cons, size)
end

function TypeInfo(def::TypeDef, info::Dict{Variant, VariantInfo})
    vars = map(x->x.name, def.typevars)
    bounded_vars = typevars_to_expr(def)
    is_concrete = all(x->x.is_concrete, values(info))
    size = is_concrete ? TypeSize(def, info) : GeneratedTypeSize()
    storage = Storage(def, size, vars, bounded_vars)
    name = TypeName(def.name, vars, bounded_vars)
    variant = TypeName(Symbol("#", def.name, "#Variant"), vars, bounded_vars)
    return TypeInfo(name, variant, vars, bounded_vars, storage)
end

function GeneratedTypeSize()
    @gensym tag_byte bits_byte ptrs_byte
    return GeneratedTypeSize(tag_byte, bits_byte, ptrs_byte)
end

function TypeSize(def::TypeDef, info::Dict{Variant, VariantInfo})
    bits = count_bytes(isbitstype, f->sizeof(f.guess), info)
    ptrs = count_bytes(!isbitstype, f->1, info)
    tag = paded_tag_nbits(bits, ptrs)
    return TypeSize(tag, bits, ptrs)
end

function VariantInfo(def::TypeDef, variant::Variant, tag::Int)
    fields = Vector{FieldInfo}(undef, length(variant.fields))
    variant.kind === :singleton && return VariantInfo(
        variant, tag, true, fields
    )

    for (kth_field::Int, f::Union{Field, NamedField}) in enumerate(variant.fields)
        guess = guess_type(def, f.type)
        var = if f isa NamedField
            Symbol("##", variant.name, "#", f.name, "#", kth_field)
        else
            Symbol("##", variant.name, "#", kth_field)
        end
        get_expr = Symbol("##", variant.name, "#get#", kth_field)

        fields[kth_field] = FieldInfo(
            var,
            get_expr,
            f.type,
            isbitstype(guess),
            guess isa Type,
            guess,
        )
    end
    is_concrete = all(x->x.is_concrete, fields)
    return VariantInfo(variant, tag, is_concrete, fields)
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

function count_bytes(::typeof(isbitstype), map, info::Dict{Variant, VariantInfo})
    maximum(values(info); init=0) do info::VariantInfo
        values = Iterators.filter(f->f.is_bitstype, info.fields)
        mapfoldl(+, values; init=0) do f::FieldInfo
            map(f)
        end
    end
end

function count_bytes(::ComposedFunction{typeof(!), typeof(isbitstype)}, map, info::Dict{Variant, VariantInfo})
    maximum(values(info); init=0) do info::VariantInfo
        values = Iterators.filter(f->!f.is_bitstype, info.fields)
        mapfoldl(+, values; init=0) do f::FieldInfo
            map(f)
        end
    end
end

# do nothing for generated at compile time
function update_index!(info::Dict{Variant, VariantInfo}, size::GeneratedTypeSize)
    for (_, vinfo::VariantInfo) in info, f::FieldInfo in vinfo
        f.index = gensym(:index)
    end
    return info
end

function update_index!(info::Dict{Variant, VariantInfo}, size::TypeSize)
    for (_, vinfo::VariantInfo) in info
        start = 0; ptr = 1
        for f::FieldInfo in vinfo
            if f.is_bitstype
                stop = start+sizeof(f.guess)
                f.index = start+1:stop
                start = stop
            else
                f.index = ptr
                ptr += 1
            end
        end
    end
    return info
end

function guess_type(def::TypeDef, expr)
    function find(type::Symbol)
        for tv in def.typevars
            tv.name == type && return tv
        end
        return
    end

    expr isa Type && return expr

    if expr isa Symbol
        if (tv = find(expr); !isnothing(tv))
            return expr
        elseif isdefined(def.mod, expr)
            return getfield(def.mod, expr)
        else
            throw(SyntaxError("unknown type: $expr"; def.source))
        end
    elseif Meta.isexpr(expr, :curly)
        name = expr.args[1]
        typevars = expr.args[2:end]
        type = guess_type(def, name)
        type isa Type || throw(SyntaxError("invalid type: $expr"; def.source))

        vars, unknowns = [], Int[]
        for tv in typevars
            tv = guess_type(def, tv)
            (tv isa Union{Symbol, Expr}) && push!(unknowns, length(vars) + 1) 
            push!(vars, tv)
        end

        if isempty(unknowns)
            return type{vars...}
        else
            return expr
        end
    else
        throw(SyntaxError("invalid type: $expr"; def.source))
    end
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
            tv.name
        end
    end
end
