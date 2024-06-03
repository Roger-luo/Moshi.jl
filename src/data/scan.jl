scan_type_head(head) = scan_type_head!(TypeHead(), head)

function scan_type_head!(head::TypeHead, head_expr)
    if head_expr isa Symbol
        head.name = head_expr
    elseif Meta.isexpr(head_expr, :curly)
        scan_type_head!(head, head_expr.args[1])
        for arg_expr in head_expr.args[2:end]
            if arg_expr isa Symbol
                push!(head.params, TypeVarExpr(arg_expr))
            elseif Meta.isexpr(arg_expr, :<:)
                arg_expr.args[1] isa Symbol || throw(ArgumentError("invalid type head expression: $head_expr"))
                push!(head.params, TypeVarExpr(arg_expr.args[1], nothing, arg_expr.args[2]))
            elseif Meta.isexpr(arg_expr, :>:)
                arg_expr.args[1] isa Symbol || throw(ArgumentError("invalid type head expression: $head_expr"))
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

function scan_variant!(
        variant::Variant,
        variant_expr::SymbolOrExpr;
        doc::Maybe{String}=nothing,
        source::Maybe{LineNumberNode}=nothing
    )::Variant
    variant_expr isa Symbol && return Variant(Singleton, variant_expr, nothing, doc, source)

    if Meta.isexpr(variant_expr, :call)
        Variant(Anonymous, variant_expr.args[1], variant_expr.args[2:end], doc, source)
    elseif Meta.isexpr(variant_expr, :struct)
    else
        throw(ArgumentError("invalid variant expression: $variant_expr"))
    end
end
