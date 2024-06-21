struct StorageInfo
    name::Symbol
    head::SymbolOrExpr
    variant_head::SymbolOrExpr
    parent::Variant
    types::Vector{Any}
end

function StorageInfo(mod::Module, parent::Variant, params::Vector{Symbol})
    storage_name = Symbol("##Storage#", parent.name)
    storage_head = isempty(params) ? storage_name : Expr(:curly, storage_name, params...)
    variant_head = isempty(params) ? parent.name : Expr(:curly, parent.name, params...)

    types = if isnothing(parent.fields)
        []
    else
        [guess_type(mod, field.type) for field in parent.fields]
    end # Vector{Any}

    return StorageInfo(storage_name, storage_head, variant_head, parent, types)
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

    storages = [StorageInfo(def.mod, variant, params) for variant in def.variants]
    type_head = isempty(params) ? :Type : :(Type{$(params...)})
    return EmitInfo(def, params, whereparams, type_head, storages)
end
