struct FormatPrinter{IO_t, Indent, Leading, Print, PrintLn, Unquoted, Show, Sep}
    io::IO_t
    indent::Indent
    leading::Leading
    print::Print
    println::PrintLn
    unquoted::Unquoted
    show::Show
    sep::Sep
end

function FormatPrinter(io::IO)
    indent(n::Int) = Base.print(io, ' ' ^ n)
    leading() = indent(get(io, :indent, 0))
    print(xs...; kw...) = Base.printstyled(io, xs...; kw...)
    println(xs...; kw...) = begin
        Base.printstyled(io, xs..., '\n'; kw...)
        leading()
    end
    print_unquoted(xs...; kw...) = print(Base.sprint(Base.show_unquoted, xs...); kw...)
    show(mime, x) = Base.show(io, mime, x)
    show(x) = Base.show(io, x)

    function sep(left, right, trim::Int = 20)
        _, width = displaysize(io)
        width = min(width, 80)
        nindent = get(io, :indent, 0)
        ncontent = textwidth(string(left)) - textwidth(string(right))
        nsep = max(0, width - nindent - trim - ncontent)
        print(" ", "-"^nsep, " "; color=:light_black)
    end

    FormatPrinter(io,
        indent, leading,
        print, println,
        print_unquoted,
        show, sep
    )
end

function indent(f::FormatPrinter, n::Int = 4)
    FormatPrinter(IOContext(f.io, :indent=>get(f.io, :indent, 0) + n))
end

function Base.show(io::IO, ::MIME"text/plain", var::TypeVar)
    isnothing(var.lower) || printstyled(io, var.lower, " <: "; color=:light_cyan)
    printstyled(io, var.name; color=:light_cyan)
    isnothing(var.upper) || printstyled(io, " <: ", var.upper; color=:light_cyan)
end

function Base.show(io::IO, ::MIME"text/plain", var::Variant)
    f = FormatPrinter(io)
    f.leading()
    isnothing(var.source) || f.println(var.source; color=:light_black)
    if var.kind === :struct
        var.is_mutable && f.print("mutable "; color=:red)
        f.print("struct "; color=:red)
        f.print(var.name)

        ff = indent(f)
        for field in var.fields::Vector{NamedField}
            ff.println()
            isnothing(field.source) || (ff.println(field.source; color=:light_black))
            ff.print(field.name)
            ff.print("::"; color=:red)
            ff.unquoted(field.type; color=:light_cyan)
            if field.default !== no_default
                ff.print(" = "; color=:red)
                ff.unquoted(field.default; color=:light_cyan)
            end
        end
        f.println()
        f.print("end"; color=:red)
    elseif var.kind === :call
        f.print(var.name)
        f.print('('; color=:red)
        fields = var.fields::Vector{Field}
        if !isempty(fields)
            f.unquoted(fields[1].type; color=:light_cyan)
            for each in fields[2:end]
                f.print(", ")
                f.unquoted(each.type; color=:light_cyan)
            end
        end
        f.print(')'; color=:red)
    else # :singleton
        f.print(var.name)
    end
end

function Base.show(io::IO, mime::MIME"text/plain", def::TypeDef)
    f = FormatPrinter(io); f.leading()

    isnothing(def.source) || f.println(def.source; color=:light_black)
    f.print("@data "; color=:red)
    def.export_variants && f.print("public "; color=:red)
    f.print(def.name)
    if !isempty(def.typevars)
        f.print('{'; color=:red)
        f.show(mime, def.typevars[1])
        for each in def.typevars[2:end]
            f.print(", "; color=:light_cyan)
            f.show(mime, each)
        end
        f.print('}', color=:red)
    end

    if !isnothing(def.supertype)
        f.print(" <: "; color=:red)
        f.unquoted(def.supertype; color=:light_cyan)
    end

    f.println(" begin"; color=:red)
    vf = indent(f)
    for (idx, each) in enumerate(def.variants)
        vf.show(mime, each)

        if idx < length(def.variants)
            vf.println()
        end
    end
    f.println()
    f.print("end"; color=:red)
end # function Base.show

function Base.show(io::IO, ::MIME"text/plain", info::Storage)
    f = FormatPrinter(io); f.leading()
    f.println("Storage "; color=:light_black)
    f.print("struct "; color=:red)
    f.print(info.type, '\n'; color=:light_cyan)

    ff = indent(f, 4); ff.leading()

    ff.print("tag"); ff.print("::"; color=:red)
    ff.println("NTuple{$(info.size.tag_byte), UInt8}"; color=:light_cyan)

    ff.print("bits"); ff.print("::"; color=:red)
    ff.println("NTuple{$(info.size.bits_byte), UInt8}"; color=:light_cyan)

    ff.print("ptrs"); ff.print("::"; color=:red)
    ff.print("NTuple{$(info.size.ptrs_byte), Any}"; color=:light_cyan)

    f.println()
    f.print("end"; color=:red)

    info.size isa TypeSize && return
    f.println()
    f.print("@generated "; color=:light_cyan);
    f.print("function "; color=:red);
    f.print(info.cons, "(bits, ptrs)")
end

function Base.show(io::IO, mime::MIME"text/plain", info::TypeInfo)
    f = FormatPrinter(io)
    ff = indent(f)

    f.leading()
    f.println("# Type"; color=:light_black)
    f.print("struct "; color=:red)
    f.print(info.name.full, '\n'; color=:light_cyan)
    ff.leading()
    ff.print("data"); ff.print("::"; color=:red)
    ff.print(info.storage.cons; color=:light_cyan)
    f.println()
    f.println("end"; color=:red)
    f.println()

    f.println("# Variant"; color=:light_black)
    f.print("struct "; color=:red)
    f.print(info.variant.full, "\n"; color=:light_cyan)
    ff.leading()
    ff.print("tag"); ff.print("::"; color=:red)
    ff.print("UInt8"; color=:light_cyan)
    f.println()
    f.println("end"; color=:red)

    f.print('\n')
    f.show(mime, info.storage)
end

function Base.show(io::IO, mime::MIME"text/plain", info::VariantInfo)
    f = FormatPrinter(io); f.leading()
    f.print("[", repr(info.tag), "] "; color=:light_black)
    f.print(info.def.name)
    info.def.kind === :singleton && return

    f.print('\n')
    ff = indent(f, 2); ff.leading()
    for (idx, finfo::FieldInfo) in enumerate(info)
        ff.print("[$idx] "; color=:light_black)
        ff.print(finfo.var); ff.print("::"; color=:red)
        ff.print(finfo.expr; color=:light_cyan)
        if finfo.index isa Symbol
            index = finfo.index::Symbol
            ff.sep(finfo.expr, index)
            ff.print(index)
        elseif finfo.is_bitstype
            index = finfo.index::UnitRange{Int}
            ff.sep(finfo.expr, "bits")
            ff.print("bits[$index]")
        else
            index = finfo.index::Int
            ff.sep(finfo.expr, "ptrs")
            ff.print("ptrs[$index]")
        end

        if idx < length(info)
            ff.println()
        end
    end
end

function Base.show(io::IO, mime::MIME"text/plain", info::EmitInfo)
    f = FormatPrinter(io)
    f.print("EmitInfo for ")
    f.println(info.def.name; color=:light_cyan)
    f.print("TypeInfo: \n"; color=:light_black)
    
    ff = indent(f, 2);
    ff.show(mime, info.type)
    ff.println()

    f.println()
    f.println("Variants: "; color=:light_black)
    for (idx, (_, vinfo)) in enumerate(info.variants)
        ff.show(mime, vinfo)

        if idx < length(info.variants)
            ff.print('\n')
        end
    end
end
