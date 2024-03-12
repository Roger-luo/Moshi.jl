function emit(info::EmitInfo)
    isempty(info.cases) && return :($Base.throw($Match.SyntaxError("empty match body")))

    matches = expr_map(info.cases, info.exprs, info.lines) do case, expr, line
        pinfo = PatternInfo(info)
        if isa_variant(case, Pattern.Err)
            Expr(:block, line, :($Base.throw($Match.SyntaxError($(case.:1)))))
        else
            cond = decons(pinfo, case)(info.value_holder)
            Expr(
                :if,
                :($cond && $(check_duplicated_variables(pinfo))),
                Expr(
                    :block,
                    line,
                    quote
                        $(info.return_var) = let $(bind_match_values(pinfo)...)
                            $expr
                        end
                        @goto $(info.final_label)
                    end,
                ),
            )
        end
    end

    return Expr(
        :block,
        :($(info.value_holder) = $(info.value)),
        matches,
        last(info.lines),
        :($Base.error("matching non-exhaustic")),
        :($Base.@label $(info.final_label)),
        info.return_var,
    )
end

and_expr(lhs, rhs) = quote
    $lhs && $rhs
end

struct PatternInfo
    emit::EmitInfo
    placeholder::Symbol
    # each variable has a count
    placeholder_count::Dict{Symbol,Int}
    scope::Dict{Symbol,Set{Symbol}}
end

function PatternInfo(info::EmitInfo)
    return PatternInfo(
        info, gensym(:placeholder), Dict{Symbol,Int}(), Dict{Symbol,Set{Symbol}}()
    )
end
function placeholder!(info::PatternInfo, name::Symbol)
    count = get!(info.placeholder_count, name, 0) + 1
    info.placeholder_count[name] = count
    return Symbol(info.placeholder, "#", name, "#", count)
end

function Base.setindex!(info::PatternInfo, v::Symbol, k::Symbol)
    push!(get!(Set{Symbol}, info.scope, k), v)
    return info
end

function check_duplicated_variables(info::PatternInfo)
    stmts = []
    for (var, values) in info.scope
        length(values) > 1 || continue
        # NOTE: let's just not support 1.8-
        val_expr = xtuple(values...)
        push!(stmts, :($Base.allequal($val_expr)))
    end
    return foldl(and_expr, stmts; init=true)
end

function bind_match_values(info::PatternInfo)
    return map(collect(keys(info.scope))) do k
        :($k = $(first(info.scope[k])))
    end
end

include("decons.jl")
include("collect.jl")
include("guard.jl")
include("leafs.jl")
include("logic.jl")
include("call.jl")
include("tuple.jl")
include("vect.jl")

function decons_type_annotate(info::PatternInfo, pat::Pattern.Type)
    return function annotate(value)
        return and_expr(:($value isa $(pat.type)), decons(info, pat.body)(value))
    end
end
