struct SelfType end

"""
Syntax placeholder for self type.
"""
const Self = SelfType()
Base.show(io::IO, x::SelfType) = print(io, "Self")

@enum VariantKind begin
    Singleton = 1
    Anonymous = 2
    Named = 3
end

struct Field
    type::Union{Symbol,Expr,Type,SelfType}
    type_expr::Union{Symbol,Expr,Type}

    function Field(typename::Symbol, type::Union{Symbol,Expr})
        type isa Symbol && return new(replace_with_self(typename, type), type)
        Meta.isexpr(type, :kw) &&
            throw(SyntaxError("field type cannot be a keyword argument"))
        type = replace_with_self(typename, type)
        type_expr = replace_with_self_type(typename, type)
        return new(type, type_expr)
    end
end

struct NamedField
    name::Symbol
    type::Union{Symbol,Expr,Type,SelfType}
    type_expr::Union{Symbol,Expr,Type}
    default # no_default, expr, or literal
    source::Union{Nothing,LineNumberNode}
end

function NamedField(typename::Symbol, f::JLKwField)
    type = replace_with_self(typename, f.type)
    type_expr = replace_with_self_type(typename, type)
    return NamedField(f.name, type, type_expr, f.default, f.line)
end

struct Variant
    kind::VariantKind
    name::Symbol
    is_mutable::Bool
    fields::Union{Vector{Field},Vector{NamedField}}
    doc
    source::Union{Nothing,LineNumberNode}

    function Variant(kind, name, is_mutable, fields, doc, source)
        if kind == Named
            all(fields) do f
                f isa NamedField
            end || throw(ArgumentError("fields must be a Vector{Field}"))
        elseif kind == Anonymous
            all(fields) do f
                f isa Field
            end || throw(ArgumentError("fields must be a Vector{NamedField}"))
        elseif kind == Singleton
            isnothing(fields) ||
                isempty(fields) ||
                throw(ArgumentError("fields must be nothing or empty"))
        else
            throw(ArgumentError("kind must be Named, Anonymous, or Singleton"))
        end

        name in fieldnames(DataType) &&
            throw(SyntaxError("cannot use reserved name $name for variant", source))
        name in (:data, :tag) &&
            throw(SyntaxError("cannot use reserved name $name for variant", source))

        return new(kind, name, is_mutable, fields, doc, source)
    end
end

struct TypeDef
    mod::Module
    name::Symbol
    supertype::Union{Nothing,Symbol,Expr}
    variants::Vector{Variant}
    source::Union{Nothing,LineNumberNode}
end

function Variant(typename::Symbol, ex::Union{Symbol,Expr}, source=nothing)
    if Meta.isexpr(ex, :macrocall) && ex.args[1] == GlobalRef(Core, Symbol("@doc"))
        source = ex.args[2]
        doc = ex.args[3]
        ex = ex.args[4]
    else
        doc = nothing
    end

    if Meta.isexpr(ex, :struct)
        def = JLKwStruct(ex)
        def.ismutable && throw(SyntaxError("mutable structs are not supported"; source))
        Variant(
            Named, def.name, def.ismutable, NamedField.(typename, def.fields), doc, source
        )
    elseif Meta.isexpr(ex, :call)
        ex.args[1] isa Symbol || throw(SyntaxError("variant name must be a symbol"; source))
        Variant(Anonymous, ex.args[1], false, Field.(typename, ex.args[2:end]), doc, source)
    elseif ex isa Symbol
        Variant(Singleton, ex, false, Field[], doc, source)
    else
        throw(SyntaxError("variant must be a struct, call, or symbol"; source))
    end
end

function TypeDef(mod::Module, head, body::Expr; source=nothing)
    name, supertype = scan_data_head(head, source)
    name === :Type && throw(SyntaxError("cannot use reserved name Type for type"; source))

    variants = Variant[]
    let source = source
        for each in body.args
            each isa LineNumberNode && (source = each; continue)
            push!(variants, Variant(name, each, source))
        end
    end # let

    length(variants) > 0 ||
        throw(SyntaxError("type $name must have at least one variant"; source))
    length(variants) > 256 &&
        throw(SyntaxError("too many variants in type $name, 256 maximum"; source))
    return TypeDef(mod, name, supertype, variants, source)
end

function scan_data_head(head, source=nothing)
    if Meta.isexpr(head, :<:)
        name, _ = scan_data_head(head.args[1])
        supertype = head.args[2]
    elseif Meta.isexpr(head, :curly)
        throw(
            ArgumentError(
                "type parameters are not allowed, we do not support generic ADTs yet"
            ),
        )
    elseif head isa Symbol
        name = head
        supertype = nothing
    else
        throw(ArgumentError("type name must be a symbol or curly expression"))
    end
    return name, supertype
end

function is_self_ref(name::Symbol, expr)
    expr isa Symbol && expr === name && return true
    expr isa Symbol && return false
    Meta.isexpr(expr, :.) || return false
    expr.args[1] === name || return false
    expr.args[2] isa QuoteNode || return false
    expr.args[2].value === :Type && return true
    return false
end

function replace_with_self(name::Symbol, expr)
    is_self_ref(name, expr) && return Self
    expr isa Expr || return expr
    return Expr(expr.head, map(x -> replace_with_self(name, x), expr.args)...)
end

function replace_with_self_type(name::Symbol, expr)
    expr isa SelfType && return :($name.Type)
    expr isa Expr || return expr
    return Expr(expr.head, map(x -> replace_with_self_type(name, x), expr.args)...)
end
