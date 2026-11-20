"Thrown when a check runs out of steps."
struct OutOfSteps <: Exception end

"Steps a check may still take."
mutable struct Budget
    steps::Int
end

"Charge `steps` to `budget`; throw `OutOfSteps` when it runs out."
function spend!(budget::Budget, steps::Int)::Nothing
    budget.steps -= steps
    budget.steps < 0 && throw(OutOfSteps())
    return nothing
end
