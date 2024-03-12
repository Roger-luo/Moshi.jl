@pass 3 function emit_storage_cons(info::EmitInfo)
    @gensym tag bits ptrs
    quote
        function $(info.type.storage.name)(tag::UInt8, bits::$Core.Tuple, ptrs::$Core.Tuple)
            $tag = $(xtuple(
                :tag, (zero(UInt8) for _ in 1:(info.type.storage.size.tag - 1))...
            ))
            $bits = $Data.unsafe_padded_reinterpret(
                NTuple{$(info.type.storage.size.bits),UInt8}, bits
            )
            $ptrs = $Data.padded_tuple_any($Base.Val($(info.type.storage.size.ptrs)), ptrs)
            return $(info.type.storage.name)($tag, $bits, $ptrs)
        end
    end
end

@pass 4 function emit_cons(info::EmitInfo)
    quote
        function (type::$(info.type.variant))(args...; kwargs...)
            return $(emit_cons_body(info))
        end
    end
end

function emit_cons_body(info::EmitInfo)
    foreach_variant(info, :(type.tag)) do variant::Variant, vinfo::VariantInfo
        emit_variant_cons(info, variant, vinfo)
    end
end

function emit_variant_cons(info::EmitInfo, variant::Variant, vinfo::VariantInfo)
    if (variant.kind === Singleton || variant.kind === Anonymous)
        return emit_positional_cons(info, variant, vinfo)
    end

    # variant.kind === Named
    jl = JLIfElse()
    jl[:($Base.length(args) == $(length(vinfo)))] = quote
        $(emit_positional_cons(info, variant, vinfo))
    end
    jl[:($Base.isempty(args))] = quote
        $(emit_kwargs_cons(info, variant, vinfo))
    end

    has_optional = any(variant.fields) do field::NamedField
        field.default != no_default
    end

    if has_optional
        jl[:($Base.:(<)($Base.length(args), $(length(vinfo))))] = quote
            $(emit_positional_kw_cons(info, variant, vinfo))
        end
    end

    type_name = String(info.def.name)
    vname = String(variant.name)
    jl.otherwise = quote
        $Core.throw($ArgumentError("wrong number of arguments for $($(type_name)).$($vname)"))
    end
    return codegen_ast(jl)
end

function emit_kwargs_cons(info::EmitInfo, variant::Variant, vinfo::VariantInfo)
    bits, ptrs = Expr(:tuple), Expr(:tuple)
    body = expr_map(enumerate(vinfo)) do (kth_field, finfo)
        @gensym kw val
        field = variant.fields[kth_field]::NamedField
        get_kw = if field.default === no_default
            quote
                $Base.haskey(kwargs, $(QuoteNode(field.name))) || $Core.throw(
                    $ArgumentError("missing keyword argument $($(field.name))")
                )
                kwargs[$(QuoteNode(field.name))]
            end
        else
            f_default = cons_default(info.def.mod, field.default)
            quote
                $Base.get(kwargs, $(QuoteNode(field.name)), $f_default)
            end
        end

        if finfo.is_bitstype
            push!(bits.args, val)
        else
            push!(ptrs.args, val)
        end

        # TODO: correct this, use original type
        quote
            $kw = $get_kw
            $val = $Base.convert($(finfo.type), $kw)
        end
    end

    return quote
        $body
        $(info.type.name)($(info.type.storage.name)(type.tag, $bits, $ptrs))
    end
end

function emit_positional_cons(info::EmitInfo, variant::Variant, vinfo::VariantInfo)
    bits_expr, ptrs_expr = Expr(:tuple), Expr(:tuple)
    for (kth_field, finfo::FieldInfo) in enumerate(vinfo)
        finfo.is_bitstype &&
            push!(bits_expr.args, :($Base.convert($(finfo.type), args[$kth_field])))

        !finfo.is_bitstype &&
            push!(ptrs_expr.args, :($Base.convert($(finfo.type), args[$kth_field])))
    end

    @gensym bits ptrs
    type_name = String(info.def.name)
    vname = String(variant.name)
    return quote
        $Base.length(args) == $(length(vinfo)) || $Core.throw(
            $ArgumentError(
                "wrong number of arguments for $($(type_name)).$($vname), expect $($(length(vinfo)))",
            ),
        )
        $bits = $bits_expr
        $ptrs = $ptrs_expr
        $(info.type.name)($(info.type.storage.name)(type.tag, $bits, $ptrs))
    end
end

# NOTE: this is useful when expr contains meta info, e.g hash
# <variant>(<no_default...>; kw=<has_default...>)
function emit_positional_kw_cons(info::EmitInfo, variant::Variant, vinfo::VariantInfo)
    arg_count = 0
    bits_expr, ptrs_expr = Expr(:tuple), Expr(:tuple)
    for (kth_field, finfo) in enumerate(vinfo)
        field = variant.fields[kth_field]::NamedField
        value = if field.default === no_default # arg
            arg_count += 1
            :(args[$arg_count])
        else # kw
            f_default = cons_default(info.def.mod, field.default)
            :($Base.get(kwargs, $(QuoteNode(field.name)), $f_default))
        end
        value = :($Base.convert($(finfo.type), $value))
        if finfo.is_bitstype
            push!(bits_expr.args, value)
        else
            push!(ptrs_expr.args, value)
        end
    end

    @gensym bits ptrs
    type_name = String(info.def.name)
    vname = String(variant.name)
    return quote
        $Base.length(args) == $(arg_count) || $Core.throw(
            $ArgumentError(
                "wrong number of arguments for $($(type_name)).$($vname), expect $($arg_count)",
            ),
        )
        $bits = $bits_expr
        $ptrs = $ptrs_expr
        $(info.type.name)($(info.type.storage.name)(type.tag, $bits, $ptrs))
    end
end

# call the default_expr in current module
# instead of the baremodule of ADT
function cons_default(mod::Module, default_expr)
    default_expr isa Symbol && return :($mod.$default_expr)
    if Meta.isexpr(default_expr, :.)
        return Expr(:., cons_default(mod, default_expr.args[1]), default_expr.args[2])
    elseif Meta.isexpr(default_expr, :call)
        return Expr(
            :call, cons_default(mod, default_expr.args[1]), default_expr.args[2:end]...
        )
    else
        return default_expr
    end
end
