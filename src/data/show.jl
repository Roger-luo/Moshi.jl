function Base.show(io::IO, mime::MIME"text/plain", def::TypeDef)
    printstyled(io, def.source; color=:light_black)
    println(io)
    printstyled(io, "@data "; color=:red)
    show(io, def.head)
    printstyled(io, " begin\n"; color=:red)
    for variant in def.variants
        show(IOContext(io, :indent=>4), mime, variant)
        print(io, "\n")
    end
    printstyled(io, "end"; color=:red)
end

function Base.show(io::IO, head::TypeHead)
    print(io, head.name)
    if !isempty(head.params)
        print(io, "{")
        print(io, head.params[1])
        for param in head.params[2:end]
            print(io, ", ", param)
        end
        print(io, "}")
    end
    if head.supertype !== nothing
        print(io, " <: ")
        printstyled(io, head.supertype, color=:cyan)
    end
end

function Base.show(io::IO, ::MIME"text/plain", x::Variant)
    tab(n) = print(io, " "^n)
    indent = get(io, :indent, 0)
    if !isnothing(x.doc)
        println(io)
        tab(indent)
        printstyled(io, "\"\"\"\n"; color=:yellow)
        tab(indent)
        printstyled(io, x.doc; color=:yellow)
        print(io, "\n")
        tab(indent)
        printstyled(io, "\"\"\"\n"; color=:yellow)
    end

    if x.kind == Singleton
        tab(indent)
        print(io, x.name)
    elseif x.kind == Anonymous
        tab(indent)
        print(io, x.name)
        print(io, "(")
        print(io, x.fields[1])
        for field in x.fields[2:end]
            print(io, ", ", field)
        end
        print(io, ")")
    else
        tab(indent); printstyled(io, "struct "; color=:red)
        print(io, x.name, "\n")
        for field in x.fields
            tab(indent + 4); print(io, field, "\n")
        end
        tab(indent); printstyled(io, "end"; color=:red)
    end
end

Base.show(io::IO, x::Field) = printstyled(io, x.type, color=:cyan)

function Base.show(io::IO, x::NamedField)
    print(io, x.name, "::")
    printstyled(io, x.type, color=:cyan)
    if x.default !== no_default
        printstyled(io, " = ", color=:red)
        print(io, x.default)
    end
end
