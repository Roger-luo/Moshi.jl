# concrete
function TypeDef(mod::Module, head, body::Expr; source::LineNumberNode=LineNumberNode(0))
    head = TypeHead(head)
    Meta.isexpr(body, :block) ||
        throw(ArgumentError("expect begin ... end block, got $body"))
    variants = Variant[]
    current_line = nothing
    for expr in body.args
        if expr isa LineNumberNode
            current_line = expr
            continue
        elseif isnothing(expr) # sometimes there are generated nothing in the block
            continue
        end
        push!(variants, Variant(expr; source=current_line))
    end
    return TypeDef(mod, head, variants, source)
end

TypeHead(head) = scan_type_head!(TypeHead(), head)

function scan_type_head!(head::TypeHead, head_expr)
    if head_expr isa Symbol
        head.name = head_expr
    elseif Meta.isexpr(head_expr, :curly)
        scan_type_head!(head, head_expr.args[1])
        for arg_expr in head_expr.args[2:end]
            if arg_expr isa Symbol
                push!(head.params, TypeVarExpr(arg_expr))
            elseif Meta.isexpr(arg_expr, :<:)
                arg_expr.args[1] isa Symbol ||
                    throw(ArgumentError("invalid type head expression: $head_expr"))
                push!(head.params, TypeVarExpr(arg_expr.args[1], nothing, arg_expr.args[2]))
            elseif Meta.isexpr(arg_expr, :>:)
                arg_expr.args[1] isa Symbol ||
                    throw(ArgumentError("invalid type head expression: $head_expr"))
                push!(head.params, TypeVarExpr(arg_expr.args[1], arg_expr.args[2], nothing))
            else
                throw(ArgumentError("invalid type head expression: $head_expr"))
            end
        end # for
    elseif Meta.isexpr(head_expr, :<:)
        scan_type_head!(head, head_expr.args[1])
        head.supertype = head_expr.args[2]
    else
        throw(ArgumentError("invalid type head expression: $head_expr"))
    end
    return head
end

function Variant(expr::Symbol; doc=nothing, source=nothing)
    return Variant(Singleton, expr, nothing, doc, source)
end

function Variant(expr::Expr; doc=nothing, source=nothing)
    if Meta.isexpr(expr, :call)
        expr.args[1] isa Symbol || throw(ArgumentError("invalid variant expression: $expr"))
        length(expr.args) > 1 || throw(
            ArgumentError(
                "missing fields in variant expression: $expr, do you mean to use $(expr.args[1])?",
            ),
        )
        return Variant(Anonymous, expr.args[1], Field.(expr.args[2:end]), doc, source)
    elseif Meta.isexpr(expr, :struct)
        jl = JLKwStruct(expr)
        jl.ismutable &&
            throw(ArgumentError("invalid variant expression: $expr, cannot be mutable"))
        isempty(jl.constructors) || throw(
            ArgumentError("invalid variant expression: $expr, cannot have constructors")
        )
        isnothing(jl.supertype) ||
            throw(ArgumentError("invalid variant expression: $expr, cannot have supertype"))
        isempty(jl.typevars) ||
            throw(ArgumentError("invalid variant expression: $expr, cannot have typevars"))
        return Variant(Named, jl.name, NamedField.(jl.fields), doc, source)
    elseif Meta.isexpr(expr, :macrocall) && (
        expr.args[1] === GlobalRef(Core, Symbol("@doc")) || expr.args[1] === Symbol("@doc")
    ) # allow calling @doc inside the macro
        return Variant(expr.args[4]; doc=expr.args[3], source=expr.args[2])
    elseif Meta.isexpr(expr, :curly)
        throw(
            ArgumentError(
                "invalid variant expression: $expr, variant cannot have type parameters"
            ),
        )
    else
        throw(ArgumentError("invalid variant expression: $expr"))
    end
end

function NamedField(expr::JLKwField; source=nothing)
    return NamedField(expr.name, expr.type, expr.default, expr.line)
end
