@pass 2 function emit_type(info::EmitInfo)
    union_params = if isempty(info.params)
        [storage.name for storage in info.storages]
    else
        [:($(storage.name){$(info.params...)}) for storage in info.storages]
    end

    jl = JLStruct(;
        name=Symbol("typeof($(info.def.head.name))"),
        fields=[JLField(; name=:data, type=:(Union{$(union_params...)}), isconst = info.def.ismutable)],
        typevars=info.whereparams,
	supertype=isnothing(info.def.head.supertype) ? nothing : guess_self_as_any(info.def, info.def.head.supertype),
	    ismutable = info.def.ismutable,
    )

    binding = if isempty(info.params)
        :(const Type = $(jl.name))
    else
        :(const Type{$(info.params...)} = $(jl.name){$(info.params...)})
    end

    return quote
        $(codegen_ast(jl))
        $binding
    end
end
