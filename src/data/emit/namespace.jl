@pass function emit_type_getproperty(info::EmitInfo)
    body = JLIfElse()
    for variant::Variant in info.def.variants
        vinfo = info.variants[variant]::VariantInfo
        body[:(f === $(QuoteNode(variant.name)))] = quote
            return $(info.type.variant.cons)($(vinfo.tag))
        end
    end
    body.otherwise = quote
        return $Core.throw($Base.ArgumentError(
            "invalid variant name: $f"
        ))
    end
    reserved = (fieldnames(DataType)..., :data, :tag)

    jl = JLFunction(;
        name = :($Base.getproperty),
        args = [
            :(type::Type{$(info.type.name.cons)}),
            :(f::Symbol),
        ],
        whereparams = isempty(info.type.bounded_vars) ? nothing : info.type.bounded_vars,
        body = quote
            f in $(reserved) && return $Core.getfield(type, f)
            $(codegen_ast(body))
        end
    )
    codegen_ast(jl)
end

@pass function emit_type_propertynames(info::EmitInfo)
    variant_names = map(info.def.variants) do variant::Variant
        variant.name
    end
    names = (fieldnames(DataType)..., variant_names...)

    jl = JLFunction(;
        name = :($Base.propertynames),
        args = [
            :(type::Type{$(info.type.name.cons)}),
        ],
        whereparams = isempty(info.type.bounded_vars) ? nothing : info.type.bounded_vars,
        body = quote
            $(names)
        end
    )

    codegen_ast(jl)
end

function emit_binding(info::EmitInfo)
    bindings = expr_map(info.def.variants) do variant::Variant
        jl = JLStruct(;
            name=variant.name,
            typevars=info.type.bounded_vars,
            misc=[:(1 + 1)]
        )
        codegen_ast(jl)
    end
    cons = expr_map(info.def.variants) do variant::Variant
        vinfo = info.variants[variant]::VariantInfo
        name = if isempty(info.type.vars)
            variant.name
        else
            :($(variant.name){$(info.type.vars...)})
        end
        jl = JLFunction(;
            name,
            args = [:(args...)],
            kwargs = [:(kwargs...)],
            whereparams = isempty(info.type.bounded_vars) ? nothing : info.type.bounded_vars,
            body = quote
                variant = $(info.type.variant.cons)($(vinfo.tag))
                variant(args...; kwargs...)
            end
        )
        codegen_ast(jl)
    end

    return quote
        $bindings
        $cons
    end
end
