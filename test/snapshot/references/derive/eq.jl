begin
    Base.@constprop :aggressive function Base.:(==)(lhs::EqT, rhs::EqT) where EqT <: Shape.Type
            Data.variant_type(lhs) == Data.variant_type(rhs) || return false
            vtype = Data.variant_type(lhs)
            return if vtype <: Main.TestSnapshot.Shape.Circle
                    anymissing_1 = false
                    lhs_value_1 = Base.getproperty(lhs, $(QuoteNode(1)))
                    rhs_value_1 = Base.getproperty(rhs, $(QuoteNode(1)))
                    eq_1 = Base.:(==)(lhs_value_1, rhs_value_1)
                    if Base.ismissing(eq_1)
                        anymissing_1 = true
                    else
                        eq_1 || return false
                    end
                    return if anymissing_1
                            Base.missing
                        else
                            true
                        end
                elseif vtype <: Main.TestSnapshot.Shape.Rect
                    anymissing_2 = false
                    lhs_value_2 = Base.getproperty(lhs, :w)
                    rhs_value_2 = Base.getproperty(rhs, :w)
                    eq_2 = Base.:(==)(lhs_value_2, rhs_value_2)
                    if Base.ismissing(eq_2)
                        anymissing_2 = true
                    else
                        eq_2 || return false
                    end
                    lhs_value_3 = Base.getproperty(lhs, :h)
                    rhs_value_3 = Base.getproperty(rhs, :h)
                    eq_3 = Base.:(==)(lhs_value_3, rhs_value_3)
                    if Base.ismissing(eq_3)
                        anymissing_2 = true
                    else
                        eq_3 || return false
                    end
                    return if anymissing_2
                            Base.missing
                        else
                            true
                        end
                else
                    return false
                end
        end
    Base.@constprop :aggressive function Base.isequal(lhs::EqT, rhs::EqT) where EqT <: Shape.Type
            Data.variant_type(lhs) == Data.variant_type(rhs) || return false
            vtype = Data.variant_type(lhs)
            return if vtype <: Main.TestSnapshot.Shape.Circle
                    lhs_value_4 = Base.getproperty(lhs, $(QuoteNode(1)))
                    rhs_value_4 = Base.getproperty(rhs, $(QuoteNode(1)))
                    Base.isequal(lhs_value_4, rhs_value_4) || return false
                    return true
                elseif vtype <: Main.TestSnapshot.Shape.Rect
                    lhs_value_5 = Base.getproperty(lhs, :w)
                    rhs_value_5 = Base.getproperty(rhs, :w)
                    Base.isequal(lhs_value_5, rhs_value_5) || return false
                    lhs_value_6 = Base.getproperty(lhs, :h)
                    rhs_value_6 = Base.getproperty(rhs, :h)
                    Base.isequal(lhs_value_6, rhs_value_6) || return false
                    return true
                else
                    return false
                end
        end
end
