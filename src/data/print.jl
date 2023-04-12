function Base.show(io::IO, ::MIME"text/plain", var::TypeVar)
    isnothing(var.lower) || printstyled(io, var.lower, " <: "; color=:light_cyan)
    printstyled(io, var.name; color=:light_cyan)
    isnothing(var.upper) || printstyled(io, " <: ", var.upper; color=:light_cyan)
end

function Base.show(io::IO, ::MIME"text/plain", var::Variant)
    indent(n::Int) = Base.print(io, ' ' ^ n)
    print(xs...; kw...) = printstyled(io, xs...; kw...)
    println(xs...; kw...) = begin
        printstyled(io, xs..., '\n'; kw...)
        indent(get(io, :indent, 0))
    end
    print_unquoted(xs...; kw...) = print(sprint(Base.show_unquoted, xs...); kw...)

    indent(get(io, :indent, 0))
    isnothing(var.source) || println(var.source; color=:light_black)
    if var.kind === :struct
        var.is_mutable && print("mutable "; color=:red)
        print("struct "; color=:red)
        println(var.name)
        for field in var.fields::Vector{NamedField}
            isnothing(field.source) || (println(field.source; color=:light_black))
            indent(4); print(field.name)
            print("::"; color=:red)
            print_unquoted(field.type; color=:light_cyan)
            if field.default !== no_default
                print(" = "; color=:red)
                print_unquoted(field.default; color=:light_cyan)
            end
            println()
        end
        print("end"; color=:red)
    elseif var.kind === :call
        print(var.name)
        print('('; color=:red)
        fields = var.fields::Vector{Field}
        if !isempty(fields)
            print_unquoted(fields[1].type; color=:light_cyan)
            for each in fields[2:end]
                print(", ")
                print_unquoted(each.type; color=:light_cyan)
            end
        end
        print(')'; color=:red)
    else # :singleton
        print(var.name)
    end
end

function Base.show(io::IO, mime::MIME"text/plain", def::TypeDef)
    print(xs...; kw...) = printstyled(io, xs...; kw...)
    println(xs...; kw...) = printstyled(io, xs..., '\n'; kw...)

    isnothing(def.source) || println(def.source; color=:light_black)
    print("@data "; color=:red)
    def.export_variants && print("public "; color=:red)
    print(def.name)
    if !isempty(def.typevars)
        print('{'; color=:red)
        show(io, mime, def.typevars[1])
        for each in def.typevars[2:end]
            print(", "; color=:light_cyan)
            show(io, mime, each)
        end
        print('}', color=:red)
    end

    if !isnothing(def.supertype)
        print(" <: "; color=:red)
        print(sprint(Base.show_unquoted, def.supertype); color=:light_cyan)
    end

    println(" begin"; color=:red)
    for each in def.variants
        show(IOContext(io, :indent=>4), mime, each)
        println()
    end
    print("end"; color=:red)
end # function Base.show

function Base.show(io::IO, ::MIME"text/plain", info::EmitInfo)
    indent(n::Int) = Base.print(io, ' ' ^ n)
    print(xs...; kw...) = printstyled(io, xs...; kw...)
    println(xs...; kw...) = begin
        printstyled(io, xs..., '\n'; kw...)
        indent(get(io, :indent, 0))
    end
    print_unquoted(xs...; kw...) = print(sprint(Base.show_unquoted, xs...); kw...)

    indent(get(io, :indent, 0))
    println("EmitInfo:")
    if info.size isa EmitGeneratedSize
        indent(2)
        println("# require generated function"; color=:light_black)
    end
    indent(2); print("primitive type "; color=:red);
    print("var\"", info.typename, "\" "; color=:light_cyan)
    print(8; color=:magenta)
    println(" end"; color=:red)

    indent(2); print("struct "; color=:red)
    print("var\"", info.storage, "\""; color=:light_cyan)

    def = info.parent::TypeDef
    if info.size isa EmitGeneratedSize
        print("{"; color=:red)
        for tv in def.typevars
            show(io, MIME"text/plain"(), tv)
            print(", "; color=:light_cyan)
        end
        print("var\"", info.size.bits, "\", "; color=:light_cyan)
        print("var\"", info.size.ptrs, '"'; color=:light_cyan)
        println("}"; color=:red)
        indent(6); print("bits")
        print("::"; color=:red)
        println("NTuple{var\"", info.size.bits, "\", UInt8}"; color=:light_cyan)
        indent(6); print("ptrs")
        print("::"; color=:red)
        println("NTuple{var\"", info.size.ptrs, "\", Any}"; color=:light_cyan)
    else
        println()
        indent(6); print("bits")
        print("::"; color=:red)
        println("NTuple{", info.size.bits, ", UInt8}"; color=:light_cyan)
        indent(6); print("ptrs")
        print("::"; color=:red)
        println("NTuple{", info.size.ptrs, ", Any}"; color=:light_cyan)
    end
    indent(2); println("end"; color=:red)
    println()

    indent(2); print("struct "; color=:red)
    print(def.name)
    if !isempty(def.typevars)
        print('{'; color=:red)
        show(io, MIME"text/plain"(), def.typevars[1])
        for each in def.typevars[2:end]
            print(", "; color=:light_cyan)
            show(io, MIME"text/plain"(), each)
        end
        print('}', color=:red)
    end
    println()
    indent(6); print("tag"); print("::"; color=:red)
    println("var\"", info.typename, "\""; color=:light_cyan)
    indent(6); print("data"); print("::"; color=:red)
    print("var\"", info.storage, "\""; color=:light_cyan)
    if info.size isa EmitGeneratedSize
        print("{"; color=:red)
        print_unquoted(def.typevars[1].name; color=:light_cyan)
        for tv in def.typevars[2:end]
            print(", "; color=:light_cyan)
            print_unquoted(tv.name; color=:light_cyan)
        end
        print("}"; color=:red)
    end

    println()
    indent(2); print("end"; color=:red)
end
