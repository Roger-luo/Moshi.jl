@pass function emit_variant_cons(info::EmitInfo)
    return expr_map(x -> emit_each_variant_cons(info, x), info.storages; skip_nothing=true)
end

function emit_each_variant_cons(info::EmitInfo, storage::StorageInfo)
    args = if storage.parent.kind == Singleton
        []
    elseif storage.parent.kind == Anonymous
        [Symbol(i) for i in 1:length(storage.parent.fields)]
    else
        map(storage.parent.fields) do field::NamedField
            return field.name
        end
    end

    # Storage struct fields use `Any` whenever the declared type collapses (e.g. a
    # `Vector{Any}` field or a self-referential `Vector{Self}`), so Julia's inner
    # constructor performs no conversion. Convert each argument to its declared
    # annotation type here to restore normal struct semantics; otherwise the value
    # stored can mismatch the type assert in `getproperty`/`variant_getfield`. See #32.
    inputs = [
        :($Base.convert($(type), $(arg))) for (arg, type) in zip(args, storage.annotations)
    ]

    return quote
        $Base.@constprop :aggressive function $(storage.variant_head)(
            $(args...)
        ) where {$(info.whereparams...)}
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(inputs...)))
        end
    end
end

@pass function emit_variant_kw_cons(info::EmitInfo)
    return expr_map(
        x -> emit_each_variant_kw_cons(info, x), info.storages; skip_nothing=true
    )
end

function emit_each_variant_kw_cons(info::EmitInfo, storage::StorageInfo)
    storage.parent.kind == Named || return nothing
    isempty(storage.parent.fields) && return nothing

    args = [field.name for field in storage.parent.fields]
    # See `emit_each_variant_cons`: convert to the declared field types so the
    # stored value matches the annotation used by `getproperty`. See #32.
    inputs = [
        :($Base.convert($(type), $(arg))) for (arg, type) in zip(args, storage.annotations)
    ]
    jl = JLFunction(;
        name=storage.variant_head,
        kwargs=[
            if field.default === no_default
                field.name
            else
                Expr(:kw, field.name, eval_global_ref(info.def.mod, field.default))
            end for field in storage.parent.fields
        ],
        info.whereparams,
        body=quote
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(inputs...)))
        end,
    )

    return codegen_ast(jl)
end

function eval_global_ref(mod::Module, expr)
    if expr isa Symbol && isdefined(mod, expr)
        return GlobalRef(mod, expr)
    elseif expr isa Expr
        return Expr(expr.head, map(x -> eval_global_ref(mod, x), expr.args)...)
    else
        return expr
    end
end

@pass function emit_variant_cons_inferred(info::EmitInfo)
    return expr_map(
        x -> emit_each_variant_cons_inferred(info, x), info.storages; skip_nothing=true
    )
end

function emit_each_variant_cons_inferred(info::EmitInfo, storage::StorageInfo)
    isempty(info.params) && return nothing # no type parameters
    storage.parent.kind == Singleton && return nothing

    is_inferrable(info.params, storage) || return nothing

    names = if storage.parent.kind == Anonymous
        [Symbol(i) for i in 1:length(storage.parent.fields)]
    else
        [field.name for field in storage.parent.fields]
    end

    # The "promoting" constructor additionally accepts a parametric singleton
    # bottom (e.g. `Tree.Empty()::Tree.Type{Union{}}`) in self-referential field
    # positions and converts it to the resolved `Tree.Type{T}` before storing, so
    # `Tree.Node(5, Tree.Leaf(3), Tree.Empty())` works instead of erroring on a
    # type parameter mismatch. See issue #34.
    selfrefs = findall(is_self_ref_annotation, storage.annotations)
    isempty(selfrefs) && return codegen_ast(exact_variant_cons(info, storage, names))

    promoting = codegen_ast(promoting_variant_cons(info, storage, names))
    # When the promoting constructor is not strictly more general than the exact
    # one, their method signatures coincide and defining both would overwrite (and
    # warn). This happens unless some argument can pin the type parameters while a
    # self-reference is left as the bottom — i.e. there are multiple self-refs, or
    # a non-self-ref field mentions a type parameter.
    others_pin = any(eachindex(storage.annotations)) do i
        i in selfrefs && return false
        return any(is_inferrable(param, storage.annotations[i]) for param in info.params)
    end
    if length(selfrefs) >= 2 || others_pin
        return Expr(
            :block, codegen_ast(exact_variant_cons(info, storage, names)), promoting
        )
    else
        return promoting
    end
end

function exact_variant_cons(info::EmitInfo, storage::StorageInfo, names)
    args = [:($(name)::$(type)) for (name, type) in zip(names, storage.annotations)]
    return JLFunction(;
        name=storage.parent.name,
        args,
        info.whereparams,
        body=quote
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(names...)))
        end,
    )
end

function promoting_variant_cons(info::EmitInfo, storage::StorageInfo, names)
    bottom = :(Type{$([:(Union{}) for _ in info.params]...)})
    args = [
        if is_self_ref_annotation(type)
            :($(name)::Union{$(type),$(bottom)})
        else
            :($(name)::$(type))
        end for (name, type) in zip(names, storage.annotations)
    ]
    inputs = [
        if is_self_ref_annotation(type)
            :($Base.convert($(type), $(name)))
        else
            name
        end for (name, type) in zip(names, storage.annotations)
    ]
    return JLFunction(;
        name=storage.parent.name,
        args,
        info.whereparams,
        body=quote
            $(Expr(:meta, :inline))
            return $(info.type_head)($(storage.head)($(inputs...)))
        end,
    )
end

# A field annotation is a parametric self-reference (e.g. `Tree.Type{T}`) when it
# is a `:curly` expression headed by the ADT's own `Type` alias.
is_self_ref_annotation(type) = Meta.isexpr(type, :curly) && type.args[1] === :Type

function is_inferrable(params::Vector{Symbol}, storage::StorageInfo)
    return all(is_inferrable(param, storage) for param in params)
end

function is_inferrable(param::Symbol, storage::StorageInfo)
    return any(is_inferrable(param, each) for each in storage.annotations)
end

function is_inferrable(param::Symbol, type)
    if type isa Symbol
        return param == type
    elseif Meta.isexpr(type, :curly)
        return any(is_inferrable(param, each) for each in type.args[2:end])
    elseif Meta.isexpr(type, :call)
        return any(is_inferrable(param, each) for each in type.args[2:end])
    else
        return false
    end
end

@pass 8 function emit_variant_docs(info::EmitInfo)
    return expr_map(x -> emit_each_variant_doc(info, x), info.storages; skip_nothing=true)
end

function emit_each_variant_doc(info::EmitInfo, storage::StorageInfo)
    isnothing(storage.parent.doc) && return nothing
    raw = storage.parent.doc
    raw isa String ||
        Meta.isexpr(raw, :macrocall) ||
        throw(
            ArgumentError(
                "variant doc for $(storage.parent.name) must be a string literal or macro call, got: $(typeof(raw))",
            ),
        )
    source = something(storage.parent.source, info.def.source)
    doc = eval_global_ref(info.def.mod, raw)
    return Expr(
        :macrocall, GlobalRef(Base, Symbol("@doc")), source, doc, storage.parent.name
    )
end

# special singleton constructor with adaptive type parameters

@pass function emit_variant_cons_singleton_bottom(info::EmitInfo)
    isempty(info.params) && return nothing # no type parameters
    return expr_map(info.storages; skip_nothing=true) do storage::StorageInfo
        storage.parent.kind == Singleton || return nothing

        bottoms = [:(Union{}) for _ in 1:length(info.params)]
        jl = JLFunction(;
            name=storage.parent.name,
            body=quote
                $(Expr(:meta, :inline))
                return Type{$(bottoms...)}($(storage.name){$(bottoms...)}())
            end,
        )

        return codegen_ast(jl)
    end
end
