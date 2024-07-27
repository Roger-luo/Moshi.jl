using Jieko
using Markdown
using MarkdownAST
using AbstractTrees
using Moshi.Data

function getdocs()
    stub = getproperty(Data, Jieko.INTERFACE_STUB)
    docs = Dict{Symbol, Markdown.MD}()
    for (name, interface) in stub
        md = Docs.doc(Docs.Binding(Data, name))
        md.content[1].content[1].content[1].language = "julia"
        docs[name] = md
    end
    return docs
end # getdocs

docs = getdocs()
docs[:data_type_name].content[1].content[1].content[1]

file = joinpath(@__DIR__, "data.mdx")

open(file, "w") do io
    for (name, md) in docs
        println(name)
        print(io, """
        <Card title="$(name)">

        $md

        </Card>
        """)
    end
end # open
