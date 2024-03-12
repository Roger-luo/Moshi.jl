struct FormatPrinter{IO_t,Indent,Leading,Print,PrintLn,Unquoted,Show,ShowStr,Sep}
    io::IO_t
    indent::Indent
    leading::Leading
    print::Print
    println::PrintLn
    unquoted::Unquoted
    show::Show
    show_str::ShowStr
    sep::Sep
end

function FormatPrinter(io::IO)
    indent(n::Int) = Base.print(io, ' '^n)
    leading() = indent(get(io, :indent, 0))
    print(xs...; kw...) = Base.printstyled(io, xs...; kw...)
    println(xs...; kw...) = begin
        Base.printstyled(io, xs..., '\n'; kw...)
        leading()
    end
    print_unquoted(xs...; kw...) = print(Base.sprint(Base.show_unquoted, xs...); kw...)
    show(mime, x) = Base.show(io, mime, x)
    show(x) = Base.show(io, x)
    show_str(mime, x; kw...) = Base.sprint(Base.show, mime, x; kw...)
    show_str(x; kw...) = Base.sprint(Base.show, x; kw...)

    function sep(left, right, trim::Int=20)
        _, width = displaysize(io)
        width = min(width, 80)
        nindent = get(io, :indent, 0)
        ncontent = textwidth(string(left)) - textwidth(string(right))
        nsep = max(0, width - nindent - trim - ncontent)
        return print(" ", "-"^nsep, " "; color=:light_black)
    end

    return FormatPrinter(
        io, indent, leading, print, println, print_unquoted, show, show_str, sep
    )
end

function indent(f::FormatPrinter, n::Int=4)
    return FormatPrinter(IOContext(f.io, :indent => get(f.io, :indent, 0) + n))
end

function Base.show(io::IO, ::MIME"text/plain", var::TypeVar)
    isnothing(var.lower) || printstyled(io, var.lower, " <: "; color=:light_cyan)
    printstyled(io, var.name; color=:light_cyan)
    return isnothing(var.upper) || printstyled(io, " <: ", var.upper; color=:light_cyan)
end

function Base.show(io::IO, ::MIME"text/plain", var::Variant)
    f = FormatPrinter(io)
    f.leading()
    isnothing(var.source) || f.println(var.source; color=:light_black)
    if var.kind === Named
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
    elseif var.kind === Anonymous
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
    else # Singleton
        f.print(var.name)
    end
end

function Base.show(io::IO, mime::MIME"text/plain", def::TypeDef)
    f = FormatPrinter(io)
    f.leading()

    isnothing(def.source) || f.println(def.source; color=:light_black)
    f.print("@data "; color=:red)
    f.print(def.name)

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
    return f.print("end"; color=:red)
end # function Base.show

function Base.show(io::IO, ::MIME"text/plain", info::Storage)
    f = FormatPrinter(io)
    f.leading()
    f.println("Storage "; color=:light_black)
    f.print("struct "; color=:red)
    f.print(info.name, '\n'; color=:light_cyan)

    ff = indent(f, 4)
    ff.leading()

    ff.print("tag")
    ff.print("::"; color=:red)
    ff.println("NTuple{$(info.size.tag), UInt8}"; color=:light_cyan)

    ff.print("bits")
    ff.print("::"; color=:red)
    ff.println("NTuple{$(info.size.bits), UInt8}"; color=:light_cyan)

    ff.print("ptrs")
    ff.print("::"; color=:red)
    ff.print("NTuple{$(info.size.ptrs), Any}"; color=:light_cyan)

    f.println()
    return f.print("end"; color=:red)
end

function Base.show(io::IO, mime::MIME"text/plain", info::TypeInfo)
    f = FormatPrinter(io)
    ff = indent(f)

    f.leading()
    f.println("# Type"; color=:light_black)
    f.print("struct "; color=:red)
    f.print(info.name, '\n'; color=:light_cyan)
    ff.leading()
    ff.print("data")
    ff.print("::"; color=:red)
    ff.print(info.storage.name; color=:light_cyan)
    f.println()
    f.println("end"; color=:red)
    f.println()

    f.println("# Variant"; color=:light_black)
    f.print("struct "; color=:red)
    f.print(info.variant, "\n"; color=:light_cyan)
    ff.leading()
    ff.print("tag")
    ff.print("::"; color=:red)
    ff.print("UInt8"; color=:light_cyan)
    f.println()
    f.println("end"; color=:red)

    f.print('\n')
    return f.show(mime, info.storage)
end

function Base.show(io::IO, mime::MIME"text/plain", info::VariantInfo)
    f = FormatPrinter(io)
    f.leading()
    f.print("[", repr(info.tag), "] "; color=:light_black)
    f.print(info.def.name)
    info.def.kind === Singleton && return nothing

    f.print('\n')
    ff = indent(f, 2)
    ff.leading()
    for (idx, finfo::FieldInfo) in enumerate(info)
        ff.print("[$idx] "; color=:light_black)
        ff.print(finfo.var)
        ff.print("::"; color=:red)
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

    ff = indent(f, 2)
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

function show_variant(io::IO, data)
    f = FormatPrinter(io)
    curr_mod = Base.active_module()
    data_mod = parentmodule(data_type_module(data))
    if curr_mod != data_mod && !Base.isvisible(data_type_name(data), data_mod, curr_mod)
        f.print(data_mod)
        f.print(".")
    end
    dname = data_type_name(data)
    vname = variant_name(data)
    f.print(dname)
    f.print(".")
    f.print(vname; color=:light_cyan)
    return nothing
end

show_variant(io::IO, ::MIME, data) = show_variant(io, data)

pprint(data) = pprint(stdout, data)

"""
$SIGNATURES

Print the data type in a standard pretty format.
"""
function pprint(io::IO, data)
    f = FormatPrinter(io)
    show_variant(io, data)
    is_singleton(data) && return nothing
    f.print("(\n")
    ff = indent(f, 2)
    fnames = propertynames(data)
    for (idx, fieldname) in enumerate(fnames)
        value = getproperty(data, fieldname)
        ff.leading()
        if fieldname isa Symbol
            ff.print(fieldname, "="; color=:light_black)
            ff.show(value)
        else
            ff.show(value)
        end

        if idx < length(fnames)
            ff.print(",\n")
        end
    end
    f.println()
    return f.print(")")
end

"""
$SIGNATURES

This is the API for overloading custom pretty printing of data types.
It falls back to `pprint` if no method is defined.
"""
show_data(io::IO, data) = pprint(io, data)

"""
$SIGNATURES

Multi-line and multi-MIME version of `show_data`.
"""
show_data(io::IO, ::MIME, data) = show_data(io, data)
