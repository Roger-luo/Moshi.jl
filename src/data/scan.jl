struct StorageInfo
    name::Symbol
    parent::Variant
    types::Vector{Any}
end

function StorageInfo(mod::Module, parent::Variant)
    storage_name = Symbol("##Storage#", parent.name)
    types = if isnothing(parent.fields)
        []
    else
        [guess_type(mod, field.type) for field in parent.fields]
    end # Vector{Any}

    return StorageInfo(storage_name, parent, types)
end

struct EmitInfo
    def::TypeDef
    params::Vector{Symbol}
    whereparams::Vector{Any}
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
    storages = [StorageInfo(def.mod, variant) for variant in def.variants]
    return EmitInfo(def, params, whereparams, storages)
end
