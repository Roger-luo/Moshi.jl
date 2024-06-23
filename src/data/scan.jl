struct StorageInfo
    name::Symbol
    head::SymbolOrExpr
    variant_head::SymbolOrExpr
    parent::Variant
    types::Vector{Any} # types within the struct, Self => Any
    annotations::Vector{Any} # types used for variant functions Self => Type{...}
end

function StorageInfo(def::TypeDef, parent::Variant, params::Vector{Symbol})
    storage_name = Symbol("##Storage#", parent.name)
    storage_head = isempty(params) ? storage_name : Expr(:curly, storage_name, params...)
    variant_head = isempty(params) ? parent.name : Expr(:curly, parent.name, params...)

    types = if isnothing(parent.fields)
        []
    else
        [guess_self_as_any(def, field.type) for field in parent.fields]
    end # Vector{Any}

    annotations = if isnothing(parent.fields)
        []
    else
        [guess_self_as_annotation(def, field.type) for field in parent.fields]
    end # Vector{Any}

    return StorageInfo(storage_name, storage_head, variant_head, parent, types, annotations)
end

function guess_self_as_any(def::TypeDef, expr)
    if expr isa Type || expr isa QuoteNode
        return expr
    elseif expr isa Symbol
        expr === def.head.name && return Any
        isdefined(def.mod, expr) || return expr # type params
        return getproperty(def.mod, expr)
    elseif Meta.isexpr(expr, :.)
        if expr.args[1] === def.head.name && expr.args[2].value === :Type
            return Any
        end
        mod = guess_self_as_any(def, expr.args[1])
        return getproperty(mod, expr.args[2].value)
    elseif Meta.isexpr(expr, :curly)
        type = guess_self_as_any(def, expr.args[1])
        type === Any && return Any # no need to guess further

        typevars = map(expr.args[2:end]) do param
            guess_self_as_any(def, param)
        end
        Any in typevars && return Any # no need to specialize further
        return :($type{$(typevars...)})
    else
        return expr
    end
end

function guess_self_as_annotation(def::TypeDef, expr)
    # this only guess the single object from parent namespace
    # so we don't suffer namespace issue
    if expr isa Type || expr isa QuoteNode
        return expr
    elseif expr isa Symbol
        expr === def.head.name && return :Type
        isdefined(def.mod, expr) || return expr
        return getproperty(def.mod, expr)
    elseif Meta.isexpr(expr, :.) # <Self>.Type
        if expr.args[1] === def.head.name && expr.args[2].value === :Type
            return :Type
        end
        mod = guess_self_as_annotation(def, expr.args[1])
        return getproperty(mod, expr.args[2].value)
    elseif Meta.isexpr(expr, :curly)
        type = guess_self_as_annotation(def, expr.args[1])

        typevars = map(expr.args[2:end]) do param
            guess_self_as_annotation(def, param)
        end
        return :($type{$(typevars...)})
    else
        return expr
    end
end

struct EmitInfo
    def::TypeDef
    params::Vector{Symbol}
    whereparams::Vector{Any}
    type_head::SymbolOrExpr
    storages::Vector{StorageInfo}
end

function EmitInfo(def::TypeDef)
    params = [param.name for param in def.head.params]
    whereparams = map(def.head.params) do var
        return if isnothing(var.lb) && isnothing(var.ub)
            var.name
        elseif isnothing(var.lb)
            :($(var.name) <: $(guess_type(def.mod, var.ub)))
        elseif isnothing(var.ub)
            :($(var.name) >: $(guess_type(def.mod, var.lb)))
        else
            :($(guess_type(def.mod, var.lb)) <: $(var.name) <: $(guess_type(def.mod, var.ub)))
        end
    end

    storages = [StorageInfo(def, variant, params) for variant in def.variants]
    type_head = isempty(params) ? :Type : :(Type{$(params...)})
    return EmitInfo(def, params, whereparams, type_head, storages)
end
