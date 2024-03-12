function materialize_self(def::TypeDef, expr)
    return materialize_self(def.mod, expr, :($(def.name).Type); def.source)
end

function materialize_self(mod::Module, expr, self; source=nothing)
    expr isa Type && return expr
    expr isa SelfType && return self # always box self reference
    if expr isa Symbol
        if isdefined(mod, expr)
            return getfield(mod, expr)
        else
            throw(SyntaxError("unknown type: $expr"; source))
        end
    elseif Meta.isexpr(expr, :.)
        submod = guess_type(mod, expr.args[1]; source)
        return materialize_self(submod, expr.args[2].value, self; source)
    else
        return Expr(expr.head, [materialize_self(mod, e, self) for e in expr.args]...)
    end
end

function guess_module(mod::Module, expr)
    if expr isa Symbol && isdefined(mod, expr)
        val = getfield(mod, expr)
        val isa Module && return val
        return mod
    end

    Meta.isexpr(expr, :.) || return mod

    if expr isa Symbol
        isdefined(mod, expr) || throw(SyntaxError("unknown module: $expr"))
        return getfield(mod, expr)
    elseif Meta.isexpr(expr.args[1], :.)
        submod = guess_module(mod, expr.args[1])
        return guess_module(submod, expr.args[2].value)
    else
        throw(SyntaxError("invalid module: $expr"))
    end
end

function guess_type(mod::Module, expr; source=nothing)
    expr isa Type && return expr
    expr isa SelfType && return Any # always box self reference
    if expr isa Symbol
        if isdefined(mod, expr)
            return getfield(mod, expr)
        else
            throw(SyntaxError("unknown type: $expr"; source))
        end
    elseif Meta.isexpr(expr, :curly)
        name = expr.args[1]
        typevars = expr.args[2:end]
        type = guess_type(mod, name)
        type isa Type || throw(SyntaxError("invalid type: $expr"; source))

        vars, unknowns = [], Int[]
        for tv in typevars
            tv = guess_type(mod, tv)
            (tv isa Union{Symbol,Expr}) && push!(unknowns, length(vars) + 1)
            push!(vars, tv)
        end

        if isempty(unknowns)
            return type{vars...}
        else
            return expr
        end
    elseif Meta.isexpr(expr, :.)
        submod = guess_module(mod, expr.args[1])
        return guess_type(submod, expr.args[2].value)
    else
        return expr
    end
end

guess_type(def::TypeDef, expr) = guess_type(def.mod, expr; source=def.source)
