#=
Copyright 2020, Chris Coey, Lea Kapelevich and contributors

strengthening of the theta function towards the stability number of a graph

TODO add sparse PSD formulation
=#

using SparseArrays

struct StabilityNumber{T <: Real} <: ExampleInstanceJuMP{T}
    side::Int
    use_doublynonnegative::Bool
end

function build(inst::StabilityNumber{T}) where {T <: Float64} # TODO generic reals
    side = inst.side
    sparsity = 1 - inv(side)
    inv_graph = tril!(sprand(Bool, side, side, sparsity) + I)
    (row_idxs, col_idxs, _) = findnz(inv_graph)
    diags = (row_idxs .== col_idxs)

    model = JuMP.Model()
    JuMP.@variable(model, X[1:length(row_idxs)])
    X_diag = X[diags]
    JuMP.@objective(model, Max, 2 * sum(X) - sum(X_diag))
    JuMP.@constraint(model, sum(X_diag) == 1)
    X_lifted = sparse(row_idxs, col_idxs, X, side, side)
    X_vec = JuMP.AffExpr[X_lifted[i, j] for i in 1:side for j in 1:i]
    if inst.use_doublynonnegative
        cone_dim = length(X_vec)
        JuMP.@constraint(model, X_vec .* ModelUtilities.vec_to_svec!(ones(cone_dim)) in Hypatia.DoublyNonnegativeTriCone{T}(cone_dim))
    else
        JuMP.@constraint(model, X_vec in MOI.PositiveSemidefiniteConeTriangle(side))
        JuMP.@constraint(model, X[.!(diags)] .>= 0)
    end

    return model
end

instances[StabilityNumber]["minimal"] = [
    ((2, true),),
    ((2, false),),
    ]
instances[StabilityNumber]["fast"] = [
    ((20, true),),
    ((20, false),),
    ((50, true),),
    ((50, false),),
    ]
instances[StabilityNumber]["slow"] = [
    ((500, true),),
    ((500, false),),
    ]