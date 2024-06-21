@pass 4 function emit_stub_type(info::EmitInfo)
    return variants = expr_map(info.def.variants) do variant::Variant
        jl = JLStruct(; name=variant.name, typevars=info.whereparams, misc=[:($Base.:+(1, 1))])
        return codegen_ast(jl)
    end
end
