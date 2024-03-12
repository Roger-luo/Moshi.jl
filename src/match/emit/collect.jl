mutable struct CollectionDecons
    info::PatternInfo
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
    info::PatternInfo,
    pattern::Pattern.Type,
    children::Vector{Pattern.Type},
)
    splat_idx = 0
    splat_count = 0
    for (idx, p) in enumerate(children)
        if isa_variant(p, Pattern.Splat)
            splat_idx = idx
            splat_count += 1
        end
    end
    splat_count > 1 && error("multiple splats in pattern $pat")
    min_length = splat_idx == 0 ? length(children) : length(children) - 1
    return CollectionDecons(
        info, type(splat_idx), pattern, children, splat_idx, min_length, [], always_true
    )
end

function set_view_type_check!(view_type_check, coll::CollectionDecons)
    coll.view_type_check = view_type_check
    return coll
end

function coll_decons_until_splat!(coll::CollectionDecons, value)
    for (idx, p) in enumerate(coll.children)
        isa_variant(p, Pattern.Splat) && break
        push!(coll.stmts, decons(coll.info, p)(:($Base.@inbounds $value[$idx])))
    end
    return coll
end

function coll_decons_splat!(coll::CollectionDecons, value)
    coll.splat_idx == 0 && return coll
    p = coll.children[coll.splat_idx]
    @gensym placeholder
    stmt = if coll.splat_idx == length(coll.children) # splat is last
        quote
            $placeholder = $Base.@views($value[($(coll.splat_idx)):end])
            true
        end
    else
        nleft = length(coll.children) - coll.splat_idx
        quote
            $placeholder = $Base.@views($value[($(coll.splat_idx)):(end - $nleft)])
            true
        end
    end
    push!(coll.stmts, stmt)

    splat = decons_splat(coll.view_type_check, coll.info, p)
    push!(coll.stmts, splat(placeholder))
    return coll
end

function coll_decons_from_splat!(coll::CollectionDecons, value)
    coll.splat_idx == 0 && return nothing
    for (idx, p) in enumerate(Iterators.reverse(coll.children))
        isa_variant(p, Pattern.Splat) && break
        stmt = if idx == 1
            decons(coll.info, p)(:($Base.@inbounds($value[end])))
        else
            decons(coll.info, p)(:($Base.@inbounds($value[end - $(idx - 1)])))
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
