export @data

macro data(head, expr)
    esc(data_m(__module__, __source__, head, expr))
end

function data_m(m::Module, source::LineNumberNode, head::Union{Symbol, Expr}, expr)
    try
        emit_data(m, source, head, expr)
    catch e
        if e isa SyntaxError
            err = ArgumentError(e.msg)
            return Expr(:block, e.source, :($Core.throw($err)))
        else
            rethrow(e)
        end
    end
end

function emit_data(m::Module, source::LineNumberNode, head, expr)
    if head isa Symbol || Meta.isexpr(head, :curly)
        throw(SyntaxError("invalid data type syntax: $head"; source))
    end

    Meta.isexpr(expr, :block) || throw(
        SyntaxError("expecting begin ... end block"; source))

    def = TypeDef(m, head, expr; source)
    info = EmitInfo(def)
    return emit(info)
end
