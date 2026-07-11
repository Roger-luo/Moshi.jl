using JSON
using Jieko
using Markdown
using Moshi.Data
using Moshi.Match
using Moshi.Derive

const MODULES = [
    ("Moshi.Data", Data),
    ("Moshi.Match", Match),
    ("Moshi.Derive", Derive),
]

function render_docstr(docstr::Base.Docs.DocStr)
    parts = String[]
    for chunk in docstr.text
        chunk isa String || continue
        text = strip(chunk)
        isempty(text) && continue
        push!(parts, text)
    end
    return join(parts, "\n\n")
end

function render_binding_doc(mod::Module, name::Symbol)
    obj = getproperty(mod, name)
    m = Base.Docs.meta(mod)
    multidoc = get(m, obj, get(m, Docs.Binding(mod, name), nothing))
    isnothing(multidoc) && return ""

    docs = multidoc isa Base.Docs.MultiDoc ? collect(values(multidoc.docs)) : [multidoc]
    parts = String[]
    for docstr in docs
        docstr isa Base.Docs.DocStr || continue
        push!(parts, render_docstr(docstr))
    end
    return join(parts, "\n\n")
end

function extract_docs(mod::Module)
    stub = Jieko.stub(mod)
    docs = Dict{String, Any}[]
    seen = Set{String}()

    for (_, interface) in stub.interface
        name = string(interface.name)
        name in seen && continue
        push!(seen, name)
        push!(
            docs,
            Dict(
                "name" => name,
                "signature" => interface.doc,
                "doc" => render_binding_doc(mod, interface.name),
            ),
        )
    end

    for (name, captured) in stub.macros
        key = string(name)
        key in seen && continue
        push!(seen, key)
        push!(
            docs,
            Dict(
                "name" => key,
                "signature" => captured.doc,
                "doc" => render_binding_doc(mod, name),
            ),
        )
    end

    for (name, captured) in stub.structs
        key = string(name)
        key in seen && continue
        push!(seen, key)
        push!(
            docs,
            Dict(
                "name" => key,
                "signature" => captured.doc,
                "doc" => render_binding_doc(mod, name),
            ),
        )
    end

    sort!(docs, by = d -> d["name"])
    return docs
end

output_dir = joinpath(@__DIR__, "..", "src", "generated")
mkpath(output_dir)

for (module_name, mod) in MODULES
    docs = extract_docs(mod)
    output_path = joinpath(output_dir, "$(module_name).json")
    open(output_path, "w") do io
        JSON.print(io, docs, 2)
    end
    println("Generated $(length(docs)) entries for $(module_name)")
end
