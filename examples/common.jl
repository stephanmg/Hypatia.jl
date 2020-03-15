#=
Copyright 2020, Chris Coey, Lea Kapelevich and contributors

common code for examples
=#

using Test
import Random
using LinearAlgebra
import LinearAlgebra.BlasReal

import Hypatia
import Hypatia.ModelUtilities
import Hypatia.Cones
import Hypatia.Models
import Hypatia.Solvers

abstract type InstanceSet end
struct MinimalInstances <: InstanceSet end
struct FastInstances <: InstanceSet end
struct SlowInstances <: InstanceSet end
struct LinearOperatorsInstances <: InstanceSet end

abstract type ExampleInstance{T <: Real} end

example_tests(::Type{<:ExampleInstance}, ::InstanceSet) = Tuple[]

# NOTE this is a workaround for randn's lack of support for BigFloat
Random.randn(R::Type{BigFloat}, dims::Vararg{Int, N} where N) = R.(randn(dims...))
Random.randn(R::Type{Complex{BigFloat}}, dims::Vararg{Int, N} where N) = R.(randn(ComplexF64, dims...))

function relative_residual(residual::Vector{T}, constant::Vector{T}) where {T <: Real}
    @assert length(residual) == length(constant)
    return T[residual[i] / max(one(T), constant[i]) for i in eachindex(constant)]
end

# build model, solve, test conic certificates, and return solve information
function process_result(
    model::Models.Model{T},
    solver::Solvers.Solver{T},
    ) where {T <: Real}
    status = Solvers.get_status(solver)
    solve_time = Solvers.get_solve_time(solver)
    num_iters = Solvers.get_num_iters(solver)

    primal_obj = Solvers.get_primal_obj(solver)
    dual_obj = Solvers.get_dual_obj(solver)

    x = Solvers.get_x(solver)
    y = Solvers.get_y(solver)
    s = Solvers.get_s(solver)
    z = Solvers.get_z(solver)

    obj_diff = primal_obj - dual_obj
    compl = dot(s, z)

    (c, A, b, G, h, obj_offset) = (model.c, model.A, model.b, model.G, model.h, model.obj_offset)
    if status == :Optimal
        x_res = G' * z + A' * y + c
        y_res = A * x - b
        z_res = G * x + s - h
        x_res_rel = relative_residual(x_res, c)
        y_res_rel = relative_residual(y_res, b)
        z_res_rel = relative_residual(z_res, h)
        x_viol = norm(x_res_rel, Inf)
        y_viol = norm(y_res_rel, Inf)
        z_viol = norm(z_res_rel, Inf)
    elseif status == :PrimalInfeasible
        if dual_obj < obj_offset
            @warn("dual_obj < obj_offset for primal infeasible case")
        end
        # TODO conv check causes us to stop before this is satisfied to sufficient tolerance - maybe add option to keep going
        x_res = G' * z + A' * y
        x_res_rel = relative_residual(x_res, c)
        x_viol = norm(x_res_rel, Inf)
        y_viol = NaN
        z_viol = NaN
    elseif status == :DualInfeasible
        if primal_obj > obj_offset
            @warn("primal_obj > obj_offset for primal infeasible case")
        end
        # TODO conv check causes us to stop before this is satisfied to sufficient tolerance - maybe add option to keep going
        y_res = A * x
        z_res = G * x + s
        y_res_rel = relative_residual(y_res, b)
        z_res_rel = relative_residual(z_res, h)
        x_viol = NaN
        y_viol = norm(y_res_rel, Inf)
        z_viol = norm(z_res_rel, Inf)
    elseif status == :IllPosed
        # TODO primal vs dual ill-posed statuses and conditions
    end

    return (status = status,
        solve_time = solve_time, num_iters = num_iters,
        primal_obj = primal_obj, dual_obj = dual_obj,
        x = x, y = y, s = s, z = z,
        obj_diff = obj_diff, compl = compl,
        x_viol = x_viol, y_viol = y_viol, z_viol = z_viol)
end
