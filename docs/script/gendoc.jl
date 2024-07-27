using JSON
using Jieko
using Markdown
using Moshi.Data

function extract_docs(mod::Module)
    stub = getproperty(mod, Jieko.INTERFACE_STUB)
    docs = Dict{String, String}()
    for (name, interface) in stub
        md = Docs.doc(Docs.Binding(mod, name))
        md.content[1].content[1].content[1].language = "julia"
        docs[string(name)] = string(md)
    end
    return docs
end

docs = extract_docs(Data)
JSON.print(docs)
