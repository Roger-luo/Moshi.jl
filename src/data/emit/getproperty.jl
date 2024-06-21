@pass function emit_getproperty(info::EmitInfo)
    return expr_map(info.storages) do storage
        quote
            function $Base.getproperty(value::Type, name::Symbol)
                data = $Base.getfield(value, :data)
                return $Base.getfield(data, name)
            end
        end # quote
    end
end

@pass function emit_propertynames(info::EmitInfo)
    return expr_map(info.storages) do storage
        quote
            function $Base.propertynames(value::Type)
                data = $Base.getfield(value, :data)
                return $Base.propertynames(data)
            end
        end # quote
    end
end
