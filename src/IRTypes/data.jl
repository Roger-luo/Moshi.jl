using ExproniconLite

# poorman's ADT
macro data(name::Symbol, variants)
    esc(data_m(__module__, name, variants))
end # macro data

Base.@kwdef struct Variant
    name::Symbol
    ismutable::Bool = false
    singleton::Bool = false
    fieldnames::Vector{Symbol} = Symbol[]
    fieldtypes::Vector{Any} = Any[]
end

function expr_to_variants(expr::Expr)::Vector{Variant}
    Meta.isexpr(expr, :block) || error("variants should be a block")
    variants = filter(expr.args) do each
        each isa Symbol && return true
        if Meta.isexpr(each, :struct) || Meta.isexpr(each, :call)
            return true
        end
        return false
    end

    return map(variants) do variant
        variant isa Symbol && return Variant(name=variant, singleton=true)
        if Meta.isexpr(variant, :call)
            return Variant(name=variant.args[1], fieldtypes=variant.args[2:end])
        end
        # struct
        jlstruct = JLKwStruct(variant)
        return Variant(;
            jlstruct.name, jlstruct.ismutable,
            fieldnames=map(x->x.name, jlstruct.fields),
            fieldtypes=map(x->x.type, jlstruct.fields)
        )
    end
end

function data_m(m::Module, name, expr)
    variants = expr_to_variants(expr)
    # validate variant name
    for variant in variants
        variant.name in (:Kind, :Type) && error("variant name cannot be Kind or Type")
        :tag in variant.fieldnames && error("variant cannot have a field named tag")
        :val in variant.fieldnames && error("variant cannot have a field named val")
    end

    Expr(:toplevel, Expr(:module, true, name, quote
        const $(nameof(m)) = $m
        $(emit_kind(variants))
        $(emit_struct(name, variants))
        $(emit_variant_cons(name, variants))
        $(emit_propertynames(variants))
        $(emit_getproperty(variants))
        $(emit_binding(variants))
    end))
end

function emit_kind(variants::Vector{Variant})
    body = quote
        primitive type Tag 8 end
        Tag(idx::Integer) = $Core.bitcast(Tag, UInt8(idx))
    end
    for (idx, each) in enumerate(variants)
        push!(body.args, :(const $(each.name) = Tag($(idx-1))))
    end
    return Expr(:toplevel, Expr(:module, true, :Kind, body))
end

function emit_struct(name::Symbol, variants::Vector{Variant})
    quote
        struct Type
            tag::Kind.Tag
            val::Any
        end
    end
end

function emit_variant_cons(name::Symbol, variants::Vector{Variant})
    body = foreach_variant(variants) do variant::Variant
        n_args = length(variant.fieldtypes)
        msg = "$(variant.name) requires $n_args arguments"
        arg_body = Expr(:block)

        args = if isempty(variant.fieldnames)
            push!(arg_body.args, :(length(args) == $(n_args) || error($msg)))
            map(enumerate(variant.fieldtypes)) do (i, type)
                :($Base.convert($type, args[$i]))
            end
        else
            map(enumerate(variant.fieldnames)) do (i, name)
                msg = "missing keyword argument $name"
                push!(arg_body.args, :(haskey(kwargs, $(QuoteNode(name))) || error($msg)))
                :($name = $Base.convert($variant.fieldtypes[$i], kwargs[$(QuoteNode(name))]))
            end
        end

        return quote
            $arg_body
            return Type(Kind.$(variant.name), $(xtuple(args...)))
        end
    end

    return quote
        function (tag::Kind.Tag)(args...; kwargs...)
            $body
        end
    end
end

function emit_propertynames(variants::Vector{Variant})
    body = foreach_variant(variants) do variant::Variant
        names = map(variant.fieldnames) do each
            QuoteNode(each)
        end
        xtuple(names...)
    end

    quote
        function Base.propertynames(p::Type)
            tag = $Base.getfield(p, :tag)::Kind.Tag
            $body
        end
    end
end

function emit_getproperty(variants::Vector{Variant})
    body = foreach_variant(variants) do variant
        val_getfield = :(val = $Base.getfield(p, :val))

        if isempty(variant.fieldnames)
            type = :(Tuple{$(variant.fieldtypes...)})
            return quote
                val = $Base.getfield(p, :val)::$type
                f === :val && return val::$type
            end
        end

        return expr_map(variant.fieldnames, variant.fieldtypes) do name, type
            return :(f === $(QuoteNode(name)) && return (val.$name)::$type)
        end
    end

    quote
        function Base.getproperty(p::Type, f::Symbol)
            tag = $Base.getfield(p, :tag)::Kind.Tag
            f === :tag && return tag
            $body
        end
    end
end

function emit_binding(variants::Vector{Variant})
    bindings = Expr(:block)
    for each in variants
        name = each.name
        if each.singleton
            push!(bindings.args, :(const $name = Type(Kind.$name, nothing)))
        else
            push!(bindings.args, :(const $name = Kind.$name))
        end
    end
    return bindings
end

function foreach_variant(f, variants::Vector{Variant})
    jlifelse = JLIfElse()
    for variant in variants
        jlifelse[:(tag == Kind.$(variant.name))] = f(variant)
    end
    jlifelse.otherwise = :(error("unreachable"))
    return codegen_ast(jlifelse)
end
