using CairoMakie
using BenchmarkTools

function benchmark(mod::Module, N::Int)
    xs = getproperty(mod, :generate)(N)
    println("$(mod): $(Base.format_bytes(Base.summarysize(xs)))")
    result = @benchmark $(getproperty(mod, Symbol("main!")))($xs)
    display(result)
    return Base.summarysize(xs), minimum(result.times) / 1e6 # ms
end

function explore_size(mod::Module)
    bench_size = (10, 100, 1000, 10000)
    return [benchmark(mod, n) for n in bench_size]
end

include("base.jl")
include("dsumtypes.jl")
include("expronicon.jl")
include("moshi.jl")
include("moshi_match.jl")
include("moshi_hacky.jl")
include("sumtypes.jl")
include("unityper.jl")

data = Dict(
    "baseline" => explore_size(BaseBench),
    "DynamicSumTypes" => explore_size(DynamicSumTypesBench),
    "Expronicon" => explore_size(ExproniconBench),
    "Moshi (reflection)" => explore_size(MoshiBench),
    "Moshi (match)" => explore_size(MoshiMatchBench),
    "Moshi (hacky)" => explore_size(MoshiHackyBench),
    "SumType" => explore_size(SumTypeTest),
    "Unityper" => explore_size(UnityperBench),
)

alloc = Dict{String,Vector{Float64}}()
for (key, col) in data
    alloc[key] = map(col) do each
        each[1]
    end
end
for (key, value) in alloc
    key == "baseline" && continue
    alloc[key] = round.(value ./ alloc["baseline"], digits=2)
end
delete!(alloc, "baseline")

speed = Dict{String,Vector{Float64}}()
for (key, col) in data
    @show key
    speed[key] = map(col) do each
        each[2]
    end
end
for (key, value) in speed
    key == "baseline" && continue
    speed[key] = round.(value ./ speed["baseline"], digits=2)
end
delete!(speed, "baseline")

speed
set_theme!(theme_dark())
colors = Makie.wong_colors()
fig = Figure(size=(800, 1000), backgroundcolor=:transparent)
for (idx, size) in enumerate([10, 100, 1000, 10000])
    packages = sort(collect(keys(speed)))
    tbl = (
        cat=[i for i in 1:length(speed) for j in 1:2],
        height=[j == 1 ? alloc[key][idx] : speed[key][idx] for key in packages for j in 1:2],
        grp=[j for i in 1:length(speed) for j in 1:2],
    )

    barplot(
        fig[idx, 1],
        tbl.cat,
        tbl.height;
        dodge=tbl.grp,
        color=colors[tbl.grp],
        axis= idx == 4 ? (
            xticks=(1:length(speed), packages),
            xticklabelrotation = pi/4,
            title="# of elements: $(size)",
            xlabel="packages",
            yscale = log10,
        ) : (
            xticksvisible=false,
            xticklabelsvisible=false,
            yscale = log10,
            title="# of elements: $(size)",
        ),
    )
end

Label(fig[:, 0], "relative to baseline", rotation = pi/2)

elements = [PolyElement(polycolor = colors[1]), PolyElement(polycolor = colors[2])]
Legend(fig[1, 2], elements, ["allocation", "slowdown"], "Benchmark")
fig
save("benchmark.svg", fig)
save("benchmark.png", fig)
