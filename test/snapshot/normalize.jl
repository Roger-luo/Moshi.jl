"""
    normalize(ex)

`ex` as reviewable code: no line numbers, every gensym renamed by first appearance while
keeping its base name (`##value#12` becomes `value_1`), modules printed by name, and jumps
printed as `@goto`/`@label`. Gensyms carry a global counter, so without the renaming two
expansions of the same code would differ.
"""
function normalize(ex)
    counts = Dict{String,Int}()
    names = Dict{Symbol,Symbol}()
    function rename(sym::Symbol)
        str = string(sym)
        parts = split(str, '#'; keepempty=false)
        startswith(str, '#') && any(p -> all(isdigit, p), parts) || return sym
        return get!(names, sym) do
            base = join(filter(p -> !all(isdigit, p), parts), '_')
            n = counts[base] = get(counts, base, 0) + 1
            return Symbol(base, "_", n)
        end
    end

    walk(x) = x
    walk(x::Symbol) = rename(x)
    walk(x::Module) = nameof(x)
    walk(x::QuoteNode) = QuoteNode(walk(x.value))
    function walk(x::Expr)
        if x.head === :macrocall
            # the second argument is the call's line-number slot
            return Expr(:macrocall, walk(x.args[1]), nothing, map(walk, x.args[3:end])...)
        end
        args = Any[walk(a) for a in x.args if !(a isa LineNumberNode)]
        if x.head in (:symbolicgoto, :symboliclabel)
            name = x.head === :symbolicgoto ? Symbol("@goto") : Symbol("@label")
            return Expr(:macrocall, name, nothing, args[1])
        elseif x.head === :where && length(args) == 1
            return args[1]
        elseif x.head === :block
            # `begin` opens no scope, so a block nested as a statement can be spliced
            stmts = Any[]
            for a in args
                Meta.isexpr(a, :block) ? append!(stmts, a.args) : push!(stmts, a)
            end
            return Expr(:block, stmts...)
        end
        return Expr(x.head, args...)
    end
    return walk(ex)
end

"""
Module the snapshots are printed relative to. Julia qualifies a printed object by whether its
name is visible from this module, so printing relative to `Main` would depend on what other
tests imported there.
"""
const PRINT_CONTEXT = Module(:SnapshotContext)

"""
    snapshot(mod, ex)

The code the outermost macro call in `ex` expands to in `mod`, normalized for review.
Inner macro calls stay unexpanded, as the macro wrote them.
"""
function snapshot(mod::Module, ex)
    code = normalize(macroexpand(mod, ex; recursive=false))
    stmts = Meta.isexpr(code, :toplevel) ? code.args : [code]
    printed = (sprint(print, stmt; context=:module => PRINT_CONTEXT) for stmt in stmts)
    return join(printed, "\n\n") * "\n"
end
