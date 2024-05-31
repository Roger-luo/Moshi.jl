using Documenter
using Moshi2
using DocThemeIndigo

indigo = DocThemeIndigo.install(Configurations)

makedocs(;
    modules = [Moshi2],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical="https://Roger-luo.github.io/Moshi2.jl",
        assets=String[indigo],
    ),
    pages = [
        "Home" => "index.md",
    ],
    repo = "https://github.com/Roger-luo/Moshi2.jl",
    sitename = "Moshi2.jl",
)

deploydocs(; repo = "https://github.com/Roger-luo/Moshi2.jl")
