using Test

macro include_test_str(file::String)
    name = uppercasefirst(splitext(basename(file))[1])
    title = "Test" * name
    return esc(Expr(:toplevel, Expr(:module, true, Symbol(title), quote
        using Test
        @testset $(title) begin
            include($file)
        end
    end)))
end

include_test"scan.jl"

@testset "examples" begin
    include_test"examples/basic.jl"
    include_test"examples/data.jl"
    include_test"examples/call.jl"
    include_test"examples/expr.jl"
end

include_test"exception.jl"
