# A broadcast pattern `Cons.(a₁, ..., aₖ)` occupies the splat slot of a
# collection pattern: it consumes a run of elements, requiring each element to
# be a `Cons`, and maps each broadcast argument to a field of `Cons`.
#
#   - a variable argument (`v...` or `v`) collects that field across the run
#     into a tuple bound to `v`;
#   - a wildcard argument (`_...` or `_`) requires the field but discards it.
function decons_broadcast(ctx::PatternContext, pat::Pattern.Type)
    head = pat.head
    @gensym el ok
    isvariant = Data.is_variant_type(head)
    type_check = isvariant ? :($Data.isa_variant($el, $head)) : :($el isa $head)
    getfield_ex(idx) =
        if isvariant
            :($Data.variant_getfield($el, $head, $idx))
        else
            :($Core.getfield($el, $idx))
        end

    return function broadcast(view)
        binds = []
        for (idx, arg) in enumerate(pat.args)
            # `v...` collects into `v`; a bare `v` behaves the same way inside a
            # broadcast because a variable cannot bind element-wise over a run.
            body = isa_variant(arg, Pattern.Splat) ? arg.body : arg
            if isa_variant(body, Pattern.Variable)
                placeholder = var!(ctx, body.:1)
                ctx[body.:1] = placeholder
                push!(
                    binds,
                    :($placeholder = $Base.Tuple($(getfield_ex(idx)) for $el in $view)),
                )
            elseif isa_variant(body, Pattern.Wildcard)
                # field required (arity is checked at scan time) but discarded
            else
                error("unsupported broadcast pattern argument: $arg; \
                      only variables (`v...`) or wildcards (`_`) are allowed")
            end
        end
        return quote
            $ok = $Base.all($type_check for $el in $view)
            if $ok
                $(binds...)
            end
            $ok
        end
    end
end

function decons(::Type{Pattern.Broadcast}, ::PatternContext, pat::Pattern.Type)
    return error(
        "broadcast pattern `$(pat.head).(...)` may only appear as an element of a \
        tuple or vector pattern"
    )
end
