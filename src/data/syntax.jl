struct Field
    type::Union{Symbol, Expr}

    function Field(type::Union{Symbol, Expr})
        type isa Symbol && return new(type)
        Meta.isexpr(type, :kw) && throw(SyntaxError("field type cannot be a keyword argument"))
        new(type)
    end
end

struct NamedField
    name::Symbol
    type::Union{Symbol, Expr}
    default # no_default, expr, or literal
    source::Union{Nothing, LineNumberNode}
end

function NamedField(f::JLKwField)
    NamedField(f.name, f.type, f.default, f.line)
end

struct Variant
    kind::Symbol # :struct, :call, :singleton
    name::Symbol
    is_mutable::Bool
    fields::Union{Vector{Field}, Vector{NamedField}}
    source::Union{Nothing, LineNumberNode}

    function Variant(kind, name, is_mutable, fields, source)
        if kind == :struct
            all(fields) do f
                f isa NamedField
            end || throw(ArgumentError("fields must be a Vector{Field}"))
        elseif kind == :call
            all(fields) do f
                f isa Field
            end || throw(ArgumentError("fields must be a Vector{NamedField}"))
        elseif kind == :singleton
            isnothing(fields) || isempty(fields) || throw(ArgumentError("fields must be nothing or empty"))
        else
            throw(ArgumentError("kind must be :struct, :call, or :singleton"))
        end

        name in fieldnames(DataType) && throw(SyntaxError("cannot use reserved name $name for variant", source))
        name in (:data, :tag) && throw(SyntaxError("cannot use reserved name $name for variant", source))

        new(kind, name, is_mutable, fields, source)
    end
end

function Variant(ex::Union{Symbol, Expr}, source = nothing)
    if Meta.isexpr(ex, :struct)
        def = JLKwStruct(ex)
        def.ismutable && throw(SyntaxError("mutable structs are not supported"; source))
        Variant(:struct, def.name, def.ismutable, NamedField.(def.fields), source)
    elseif Meta.isexpr(ex, :call)
        ex.args[1] isa Symbol || throw(SyntaxError("variant name must be a symbol"; source))
        Variant(:call, ex.args[1], false, Field.(ex.args[2:end]), source)
    elseif ex isa Symbol
        Variant(:singleton, ex, false, Field[], source)
    else
        throw(SyntaxError("variant must be a struct, call, or symbol"; source))
    end
end

struct TypeVar
    name::Symbol
    upper::Union{Nothing, Symbol, Expr}
    lower::Union{Nothing, Symbol, Expr}
end

function TypeVar(expr, source = nothing)
    if expr isa Symbol
        TypeVar(expr, nothing, nothing)
    elseif Meta.isexpr(expr, :<:)
        TypeVar(expr.args[1], expr.args[2], nothing)
    elseif Meta.isexpr(expr, :comparison)
        expr.args[2] === :<: || throw(SyntaxError("invalid typevar: $expr"; source))
        expr.args[3] === :<: || throw(SyntaxError("invalid typevar: $expr"; source))
        TypeVar(expr.args[3], expr.args[5], expr.args[1])
    else
        throw(SyntaxError("invalid typevar: $expr"; source))
    end
end

struct TypeDef
    mod::Module
    name::Symbol
    typevars::Vector{TypeVar}
    supertype::Union{Nothing,Symbol,Expr}
    variants::Vector{Variant}
    source::Union{Nothing, LineNumberNode}
    export_variants::Bool
end

function TypeDef(mod::Module, head, body::Expr; source = nothing, export_variants::Bool = false)
    name, typevars, supertype = scan_data_head(head, source)
    variants = Variant[]
    let source = source
        for each in body.args
            each isa LineNumberNode && (source = each; continue)
            push!(variants, Variant(each, source))
        end
    end # let

    length(variants) > 0 || throw(SyntaxError("type $name must have at least one variant"; source))
    length(variants) > 256 && throw(SyntaxError("too many variants in type $name, 256 maximum"; source))
    return TypeDef(mod, name, typevars, supertype, variants, source, export_variants)
end

function scan_data_head(head, source = nothing)
    if Meta.isexpr(head, :<:)
        name, typevars, _ = scan_data_head(head.args[1])
        supertype = head.args[2]
    elseif Meta.isexpr(head, :curly)
        name = head.args[1]
        typevars = TypeVar.(head.args[2:end], Ref(source))
        supertype = nothing
    elseif head isa Symbol
        name = head
        typevars = TypeVar[]
        supertype = nothing
    else
        throw(ArgumentError("type name must be a symbol or curly expression"))
    end
    return name, typevars, supertype
end
