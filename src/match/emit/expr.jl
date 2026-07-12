function decons(::Type{Pattern.Expression}, ctx::PatternContext, pat::Pattern.Type)
    return function expression(value)
        # The `args` of an `Expr` is a plain `Vector{Any}`, so we reuse the
        # collection machinery to deconstruct it. This gives us splat support
        # (e.g. `:($f($arg0, $(args...)))`) and an exact length check for free,
        # matching the semantics of the `[...]` and `(...)` patterns.
        coll = CollectionDecons(ctx, pat, pat.args) do _
            :($Base.Vector)
        end
        set_view_type_check!(coll) do view, eltype
            :($Base.eltype($view) <: $eltype || $Base.all($Base.Fix2(isa, $eltype), $view))
        end
        return and_expr(
            :($value isa Expr),
            :($value.head == $(QuoteNode(pat.head))),
            coll(:($value.args)),
        )
    end
end
