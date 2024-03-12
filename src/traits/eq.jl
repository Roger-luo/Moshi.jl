module PartialEq

"""
    eq(lhs, rhs) -> Bool

Check if `lhs` is equal to `rhs`. This trait is used in
`@match`. So that one can customize the equality check.
"""
eq(lhs, rhs) = lhs == rhs
ne(lhs, rhs) = !eq(lhs, rhs)

end # PartialEq
