@pass function emit_binding(info::EmitInfo)
    return expr_map(info.def.variants) do variant::Variant
        vinfo = info.variants[variant]::VariantInfo
        binding = if variant.kind === Singleton
            quote
                const $(variant.name) = $(info.type.variant)($(vinfo.tag))()
            end
        else
            quote
                const $(variant.name) = $(info.type.variant)($(vinfo.tag))
            end
        end # if

        if isnothing(variant.doc)
            doc = default_variant_doc(info, variant)
        else
            doc = variant.doc
        end

        doc_heading = variant_heading(info, variant) * "\n\n"
        doc = if Meta.isexpr(doc, :string)
            new_doc = Expr(:string, doc_heading)
            for each in doc.args
                if each isa AbstractString
                    push!(new_doc.args, each)
                elseif each isa Symbol
                    push!(new_doc.args, :($(info.def.mod).$(each)))
                else
                    push!(new_doc.args, :($(info.def.mod).eval($(QuoteNode(each)))))
                end
            end
            new_doc
        else
            doc_heading * doc
        end

        quote
            $binding
            $Base.@doc $doc $(variant.name)
        end
    end
end

function variant_heading(info::EmitInfo, variant::Variant)
    if variant.kind === Singleton
        return """
            $(info.def.name).$(variant.name)
        """
    elseif variant.kind === Anonymous
        args = map(variant.fields) do field::Field
            "::" * string(field.type)
        end
        args = join(args, ", ")
        return """
            $(info.def.name).$(variant.name)($args)
        """
    else # variant.kind === Named
        args = map(variant.fields) do field::NamedField
            "::" * string(field.type)
        end
        args = join(args, ", ")
        kwargs = map(variant.fields) do field::NamedField
            string(field.name) * "::" * string(field.type)
        end
        kwargs = join(kwargs, ", ")
        return """
            $(info.def.name).$(variant.name)($args)
            $(info.def.name).$(variant.name)(;$kwargs)
        """
    end
end

function default_variant_doc(info::EmitInfo, variant::Variant)
    if variant.kind === Singleton
        return """
        Singleton variant of `$(info.def.name)`
        """
    elseif variant.kind === Anonymous
        return """
        Anonymous variant of `$(info.def.name)`
        """
    else
        return """
        Named variant of `$(info.def.name)`
        """
    end
end

# @pass function emit_type_getproperty(info::EmitInfo)
#     body = JLIfElse()
#     for variant::Variant in info.def.variants
#         vinfo = info.variants[variant]::VariantInfo
#         body[:(f === $(QuoteNode(variant.name)))] = quote
#             return $(info.type.variant)($(vinfo.tag))
#         end
#     end
#     body.otherwise = quote
#         return $Core.throw($Base.ArgumentError(
#             "invalid variant name: $f"
#         ))
#     end
#     reserved = (fieldnames(DataType)..., :data, :tag)

#     jl = JLFunction(;
#         name = :($Base.getproperty),
#         args = [
#             :(type::$Base.Type{$(info.type.name)}),
#             :(f::Symbol),
#         ],
#         body = quote
#             f in $(reserved) && return $Core.getfield(type, f)
#             $(codegen_ast(body))
#         end
#     )
#     codegen_ast(jl)
# end

# @pass function emit_type_propertynames(info::EmitInfo)
#     variant_names = map(info.def.variants) do variant::Variant
#         variant.name
#     end
#     names = (fieldnames(DataType)..., variant_names...)

#     jl = JLFunction(;
#         name = :($Base.propertynames),
#         args = [
#             :(type::$Base.Type{$(info.type.name)}),
#         ],
#         body = quote
#             $(names)
#         end
#     )

#     codegen_ast(jl)
# end
