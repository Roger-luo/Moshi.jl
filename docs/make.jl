using Documenter
using Moshi
using DocThemeIndigo

indigo = DocThemeIndigo.install(Moshi)

makedocs(;
    modules=[Moshi],
    format=Documenter.HTML(;
        prettyurls=!("local" in ARGS),
        canonical="https://Roger-luo.github.io/Moshi.jl",
        assets=String[indigo],
    ),
    pages=["Home" => "index.md"],
    repo="https://github.com/Roger-luo/Moshi.jl",
    sitename="Moshi.jl",
)

deploydocs(; repo="https://github.com/Roger-luo/Moshi.jl")
