@pass 3 function emit_variant_supertype(info::EmitInfo)
    return quote
        abstract type Variant end
    end
end

@pass 4 function emit_stub_type(info::EmitInfo)
    return variants = expr_map(info.def.variants) do variant::Variant
        jl = JLStruct(;
            name=variant.name,
            supertype=:Variant,
            typevars=info.whereparams,
            misc=[:($Base.:+(1, 1))],
        )
        return codegen_ast(jl)
    end
end
