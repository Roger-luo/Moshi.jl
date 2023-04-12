@data PatternError begin
    struct InvalidPattern
        msg::String
        expr::Expr
        line::LineNumberNode
    end
end
