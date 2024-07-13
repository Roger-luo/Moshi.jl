struct EmitInfo
    mod::Module
    value::Any
    cases::Vector{Pattern.Type}
    exprs::Vector{Any}
    lines::Vector{Maybe{LineNumberNode}}
    value_holder::Symbol
    final_label::Symbol
    return_var::Symbol
    source::LineNumberNode
end

function EmitInfo(mod::Module, value, body; source::LineNumberNode=LineNumberNode(0))
    # single pattern
    if Meta.isexpr(body, :call) && body.args[1] === :(=>)
        cases = [toplevel_expr2pattern(mod, body.args[2])]
        exprs = [body.args[3]]
        lines = [source]
    elseif Meta.isexpr(body, :block)
        line_info = source
        cases = Pattern.Type[]
        exprs, lines = Any[], Union{LineNumberNode,Nothing}[]
        for stmt in body.args
            if stmt isa LineNumberNode
                line_info = stmt
            elseif Meta.isexpr(stmt, :call) && stmt.args[1] === :(=>)
                push!(cases, toplevel_expr2pattern(mod, stmt.args[2]))
                push!(exprs, stmt.args[3])
                push!(lines, line_info)
            else
                throw(PatternSyntaxError("invalid pattern table: $body"; source=line_info))
            end
        end
    else
        throw(PatternSyntaxError("invalid pattern: $body"; source=source))
    end

    return EmitInfo(
        mod,
        value,
        cases,
        exprs,
        lines,
        gensym("value"),
        gensym("final"),
        gensym("return"),
        source,
    )
end

function toplevel_expr2pattern(mod::Module, expr)
    expr isa Symbol &&
        isdefined(mod, expr) &&
        return Pattern.Err("you are using a pattern variable \
                           name that is already defined \
                           in the module: $(expr). This can be \
                           ambiguous and cause unexpected behavior.")
    return expr2pattern(mod, expr)
end

const SCAN_PASS = Dict{Symbol,Function}()

macro scan(head, fn)
    return esc(scan_m(head, fn))
end

function scan_m(head, fn)
    jlfn = JLFunction(fn)
    length(jlfn.args) == 2 || throw(
        ArgumentError(
            "scan function must have 2 arguments with signature (::Module, ::Any)"
        ),
    )

    if Meta.isexpr(head, :tuple)
        heads = [each for each in head.args]
    else
        heads = [head]
    end

    registration = expr_map(heads) do head
        head isa QuoteNode || throw(ArgumentError("head must be a quote node"))
        name = isnothing(jlfn.name) ? gensym(:scan) : jlfn.name
        :($SCAN_PASS[$head] = $name)
    end

    return quote
        $fn
        $registration
    end
end

function expr2pattern(mod::Module, expr)
    expr === :_ && return Pattern.Wildcard()
    expr isa Symbol && return Pattern.Variable(expr)
    expr isa Expr || return Pattern.Quote(expr)

    for (head, fn) in SCAN_PASS
        head === expr.head && return fn(mod, expr)
    end
    return Pattern.Err("unsupported pattern expression: $(expr)")
end

@scan :$ function quote2pattern(mod::Module, expr)
    return Pattern.Quote(expr.args[1])
end

@scan :(&&) function and2pattern(mod::Module, expr)
    return Pattern.And(expr2pattern(mod, expr.args[1]), expr2pattern(mod, expr.args[2]))
end

@scan :(||) function or2pattern(mod::Module, expr)
    return Pattern.Or(expr2pattern(mod, expr.args[1]), expr2pattern(mod, expr.args[2]))
end

@scan :if function if2pattern(mod::Module, expr)
    cond = expr.args[1] # just ignore body
    return Pattern.Guard(cond)
end

@scan :generator function generator2pattern(mod::Module, expr)
    body = expr2pattern(mod, expr.args[1])
    if Meta.isexpr(expr.args[2], :filter) # contains if
        filter = expr2pattern(mod, expr.args[2].args[1])
        stmts = expr.args[2].args[2:end]
    else # just plain generator
        filter = nothing
        stmts = expr.args[2:end]
    end

    vars, iterators = Symbol[], Pattern.Type[]
    for each in stmts
        key, it = each.args
        push!(vars, key)
        push!(iterators, expr2pattern(mod, it))
    end
    return Pattern.Generator(body, vars, iterators, filter)
end

@scan :ref function ref2pattern(mod::Module, expr)
    return Pattern.Ref(expr.args[1], expr2pattern.(Ref(mod), expr.args[2:end]))
end

@scan :comprehension function comprehension2pattern(mod::Module, expr)
    return Pattern.Comprehension(generator2pattern(mod, expr.args[1]))
end

@scan :... function splat2pattern(mod::Module, expr)
    return Pattern.Splat(expr2pattern(mod, expr.args[1]))
end

@scan :ncat function ncat2pattern(mod::Module, expr)
    return Pattern.NCat(expr.args[1], expr2pattern.(Ref(mod), expr.args[2:end]))
end

@scan :hcat function hcat2pattern(mod::Module, expr)
    return Pattern.HCat(expr2pattern.(Ref(mod), expr.args))
end

@scan :vcat function vcat2pattern(mod::Module, expr)
    return Pattern.VCat(expr2pattern.(Ref(mod), expr.args))
end

@scan :typed_ncat function typed_ncat2pattern(mod::Module, expr)
    return Pattern.TypedNCat(
        expr.args[1], # type
        expr.args[2], # n
        expr2pattern.(Ref(mod), expr.args[3:end]),
    )
end

@scan :typed_hcat function typed_hcat2pattern(mod::Module, expr)
    return Pattern.TypedHCat(
        expr.args[1], # type
        expr2pattern.(Ref(mod), expr.args[2:end]),
    )
end

@scan :typed_vcat function typed_vcat2pattern(mod::Module, expr)
    return Pattern.TypedVCat(
        expr.args[1], # type
        expr2pattern.(Ref(mod), expr.args[2:end]),
    )
end

@scan :row function row2pattern(mod::Module, expr)
    return Pattern.Row(expr2pattern.(Ref(mod), expr.args))
end

@scan :nrow function nrow2pattern(mod::Module, expr)
    return Pattern.NRow(expr.args[1], expr2pattern.(Ref(mod), expr.args[2:end]))
end

@scan :vect function vect2pattern(mod::Module, expr)
    return Pattern.Vector(expr2pattern.(Ref(mod), expr.args))
end

@scan :tuple function tuple2pattern(mod::Module, expr)
    return Pattern.Tuple(expr2pattern.(Ref(mod), expr.args))
end

@scan :(=),:kw function eq2pattern(mod::Module, expr)
    return Pattern.Kw(expr.args[1], expr2pattern(mod, expr.args[2]))
end

@scan :(::) function type2pattern(mod::Module, expr)
    if length(expr.args) == 1
        value = Pattern.Wildcard()
        type = expr.args[1]
    else
        value = expr2pattern(mod, expr.args[1])
        type = expr.args[2]
    end
    # type is always a quote from parent scope
    if Meta.isexpr(type, :$)
        return Pattern.Err("type annotation is already\
        quoting values from parent scope")
    end
    return Pattern.TypeAnnotate(value, type)
end

@scan :. function dot2pattern(mod::Module, expr)
    # NOTE: let's assume all dot expression
    # refers to some existing module/struct object
    # so they gets eval-ed later in the generated
    # code
    return Pattern.Quote(expr)
end

@scan :call function call2pattern(mod::Module, expr)
    args = Pattern.Type[]
    kwargs = Dict{Symbol,Pattern.Type}()

    for each in expr.args[2:end]
        if Meta.isexpr(each, :parameters)
            for kw in each.args
                key, val = if kw isa Symbol
                    (kw, kw)
                else
                    kw.args
                end
                kwargs[key] = expr2pattern(mod, val)
            end
        else
            push!(args, expr2pattern(mod, each))
        end
    end

    # NOTE: we have to eval this so we know what type this is
    head = Base.eval(mod, expr.args[1])

    # verify
    nfields = length(args) + length(kwargs)
    if Data.is_variant_type(head) # check if our pattern is correct
        Data.variant_nfields(head) >= nfields ||
            return Pattern.Err("too many fields to match")
        Data.variant_kind(head) == Data.Anonymous &&
            length(kwargs) > 0 &&
            return Pattern.Err("cannot use named fields in anonymous variant")
    elseif Data.is_data_type(head)
        return Pattern.Err("cannot match the type of data type, specify a variant type")
    else
        Base.fieldcount(head) >= nfields || return Pattern.Err("too many fields to match")
    end
    return Pattern.Call(head, args, kwargs)
end
