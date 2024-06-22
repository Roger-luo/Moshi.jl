@pass function emit_parametric_singleton_convert(info::EmitInfo)
    isempty(info.params) && return nothing # no type parameters
    bottoms = [:(Union{}) for _ in 1:length(info.params)]
    jl = JLIfElse()
    for storage in info.storages
        storage.parent.kind == Singleton || continue
        jl[:(data isa $(storage.name))] = quote
            return $(info.type_head)($(storage.head)())
        end
    end
    head_str = string(info.def.head.name, ".", info.type_head)
    jl.otherwise = quote
        error("unexpected type conversion from \
        $($Data.variant_name(value)) to $($(head_str))")
    end

    return quote
        $Base.@assume_effects :foldable $Base.@inline function $Data.convert(
            ::$Type{$(info.type_head)}, value::Type{$(bottoms...)}
        ) where {$(info.whereparams...)}
            return $Data.convert_singleton_bottom($(info.type_head), value)
        end

        $Base.@assume_effects :foldable $Base.@inline function $Data.convert_singleton_bottom_generated(
            ::$Type{$(info.type_head)}, value::Type{$(bottoms...)}
        ) where {$(info.whereparams...)}
            data = getfield(value, :data)
            return $(codegen_ast(jl))
        end
    end
end
