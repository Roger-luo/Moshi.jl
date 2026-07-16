mutable struct CollectionDecons
    ctx::PatternContext
    type # type of the collection
    pattern::Pattern.Type # pattern to match
    children::Vector{Pattern.Type} # children of the pattern
    splat_idx::Int
    min_length::Int
    stmts::Vector{Any}
    view_type_check
end

function CollectionDecons(
    type::Function, # f(splat_idx) -> Expr
    ctx::PatternContext,
    pattern::Pattern.Type,
    children::Vector{Pattern.Type},
)
    splat_idx = 0
    splat_count = 0
    for (idx, p) in enumerate(children)
        if is_splat_like(p)
            splat_idx = idx
            splat_count += 1
        end
    end
    splat_count > 1 && error("multiple splats in pattern $pattern")
    min_length = splat_idx == 0 ? length(children) : length(children) - 1
    return CollectionDecons(
        ctx, type(splat_idx), pattern, children, splat_idx, min_length, [], always_true
    )
end

function set_view_type_check!(view_type_check, coll::CollectionDecons)
    coll.view_type_check = view_type_check
    return coll
end

# a splat (`xs...`) and a broadcast (`Cons.(z...)`) both occupy the single
# variable-length slot of a collection pattern.
function is_splat_like(p::Pattern.Type)
    return isa_variant(p, Pattern.Splat) || isa_variant(p, Pattern.Broadcast)
end

# Index of the `k`-th (1-based) leading element, relative to `firstindex` so the
# collection machinery works on non-1-based `AbstractVector`s (e.g. `OffsetArray`)
# as well as `Vector`/`Tuple` (for which `firstindex` is `1` and this folds away).
function leading_index(value, k::Int)
    k == 1 && return :($Base.firstindex($value))
    return :($Base.firstindex($value) + $(k - 1))
end

function coll_decons_until_splat!(coll::CollectionDecons, value)
    for (idx, p) in enumerate(coll.children)
        is_splat_like(p) && break
        push!(
            coll.stmts,
            decons(coll.ctx, p)(:($Base.@inbounds $value[$(leading_index(value, idx))])),
        )
    end
    return coll
end

function coll_decons_splat!(coll::CollectionDecons, value)
    coll.splat_idx == 0 && return coll
    p = coll.children[coll.splat_idx]
    @gensym placeholder
    start = leading_index(value, coll.splat_idx)
    stmt = if coll.splat_idx == length(coll.children) # splat is last
        quote
            $placeholder = $Base.@views($value[($start):end])
            true
        end
    else
        nleft = length(coll.children) - coll.splat_idx
        quote
            $placeholder = $Base.@views($value[($start):(end - $nleft)])
            true
        end
    end
    push!(coll.stmts, stmt)

    splat = if isa_variant(p, Pattern.Broadcast)
        decons_broadcast(coll.ctx, p)
    else
        decons_splat(coll.view_type_check, coll.ctx, p)
    end
    push!(coll.stmts, splat(placeholder))
    return coll
end

function coll_decons_from_splat!(coll::CollectionDecons, value)
    coll.splat_idx == 0 && return nothing
    for (idx, p) in enumerate(Iterators.reverse(coll.children))
        is_splat_like(p) && break
        stmt = if idx == 1
            decons(coll.ctx, p)(:($Base.@inbounds($value[end])))
        else
            decons(coll.ctx, p)(:($Base.@inbounds($value[end - $(idx - 1)])))
        end
        push!(coll.stmts, stmt)
    end
    return coll
end

function finish_decons(coll::CollectionDecons, value)
    cmp = coll.splat_idx == 0 ? :(==) : :(>=)
    size_check = Expr(:call, cmp, :($Base.length($value)), coll.min_length)
    return foldl(and_expr, coll.stmts; init=:($value isa $(coll.type) && $size_check))
end

function (coll::CollectionDecons)(value)
    coll_decons_until_splat!(coll, value)
    coll_decons_splat!(coll, value)
    coll_decons_from_splat!(coll, value)
    return finish_decons(coll, value)
end

always_true(xs...) = true
