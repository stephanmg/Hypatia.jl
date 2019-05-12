#=
Copyright 2018, Chris Coey and contributors
Copyright 2018, David Papp, Sercan Yildiz

modified from https://github.com/dpapp-github/alfonso/blob/master/polyOpt.m
formulates and solves the (dual of the) polynomial optimization problem for a given polynomial, described in the paper:
D. Papp and S. Yildiz. Sum-of-squares optimization without semidefinite programming
available at https://arxiv.org/abs/1712.01792
=#

import Hypatia
const HYP = Hypatia
const CO = HYP.Cones
const MO = HYP.Models
const SO = HYP.Solvers
const MU = HYP.ModelUtilities

using LinearAlgebra
using Test

include("polymindata.jl")


function build_polymin(
    polyname::Symbol,
    d::Int;
    primal_wsos::Bool = true,
    )
    # get data for polynomial and domain, only works for boxes
    (x, fn, dom, true_obj) = getpolydata(polyname)
    lbs = dom.lbs
    ubs = dom.ubs
    n = length(x)
    @assert d >= div(deg + 1, 2)

    # TODO choose which cone definition to use and cleanup below
    # generate interpolation
    # (U, pts, P0, _, _) = MU.wsos_box_params(n, d, false)
    dom = MU.Box(lbs, ubs)
    (U, pts, P0, PWts, _) = MU.interpolate(dom, d, sample = (n >= 5))

    # TODO algorithm may perform better if function evaluations are rescaled to have more reasonable norm
    # set up problem data
    if primal_wsos
        c = [-1.0]
        A = zeros(0, 1)
        b = Float64[]
        G = ones(U, 1)
        h = [fn(pts[j, :]...) for j in 1:U]
    else
        c = [fn(pts[j, :]...) for j in 1:U] # evaluate polynomial at transformed points
        A = ones(1, U) # TODO eliminate constraint and first variable
        b = [1.0]
        G = Diagonal(-1.0I, U) # TODO uniformscaling?
        h = zeros(U)
    end
    cones = [CO.WSOSPolyInterp(U, [P0, PWts...], !primal_wsos)]
    # Ls = Int[size(P0, 2)]
    # @assert Ls[1] == binomial(n + d, n)
    # gs = Vector{Float64}[ones(U)]
    # for i in 1:n
    #     # Li = size(PWts[i], 2) # TODO may be wrong
    #     di = d - 1 # degree of gi is 2
    #     Li = binomial(n + di, n)
    #     gi = [(-pts[u, i] + ubs[i]) * (pts[u, i] - lbs[i]) for u in 1:U]
    #     push!(Ls, Li)
    #     push!(gs, gi)
    # end
    # cones = [CO.WSOSPolyInterp_2(U, P0, Ls, gs, !primal_wsos)]
    cone_idxs = [1:U]

    model_data = (c, A, b, G, h, cones, cone_idxs)

    return (model_data, true_obj)
end

polymin1() = build_polymin(:butcher, 2)
polymin2() = build_polymin(:caprasse, 4)
polymin3() = build_polymin(:goldsteinprice, 6)
polymin4() = build_polymin(:heart, 2)
polymin5() = build_polymin(:lotkavolterra, 3)
polymin6() = build_polymin(:magnetism7, 2)
polymin7() = build_polymin(:motzkin, 7)
polymin8() = build_polymin(:reactiondiffusion, 4)
polymin9() = build_polymin(:robinson, 8)
polymin10() = build_polymin(:rosenbrock, 5)
polymin11() = build_polymin(:schwefel, 4)

# TODO decide how to test
# function test_polymin(instance)
#     (model_data, true_obj) = instance()
#     (c, A, b, G, h, cones, cone_idxs) = model_data
#     model = MO.PreprocessedLinearModel(c, A, b, G, h, cones, cone_idxs)
#     solver = SO.HSDSolver(model, verbose = true)
#     SO.solve(solver)
#     @test SO.get_status(solver) == :Optimal
#     return
# end
#
# test_polymin_many() = test_polymin.([
#     polymin1,
#     polymin2,
#     polymin3,
#     polymin4,
#     polymin5,
#     polymin6,
#     polymin7,
#     polymin8,
#     polymin9,
#     polymin10,
#     polymin11,
# ])
