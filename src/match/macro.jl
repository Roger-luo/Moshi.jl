macro match(expr, body)
    return esc(match_m(__module__, __source__, expr, body))
end

function match_m(mod::Module, source, expr, body)
    info = EmitInfo(mod, expr, body, source)
    return emit(info)
end
