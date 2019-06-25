#=
Copyright 2018, Chris Coey and contributors

functions and caches for cones
=#

module Cones

using LinearAlgebra
import LinearAlgebra.BlasFloat
using ForwardDiff
using DiffResults
import Hypatia.HypReal
import Hypatia.HypRealOrComplex
import Hypatia.hyp_AtA!
import Hypatia.hyp_chol!
import Hypatia.hyp_ldiv_chol_L!
import Hypatia.rt2
import Hypatia.rt2i

abstract type Cone{T <: HypReal} end

include("orthant.jl")
include("epinorminf.jl")
include("epinormeucl.jl")
include("epipersquare.jl")
include("semidefinite.jl")
include("hypoperlog.jl")
include("epiperpower.jl")
include("hypogeomean.jl")
include("epinormspectral.jl")
include("hypoperlogdet.jl")
include("hypopersumlog.jl")
include("epipersumexp.jl")
include("wsospolyinterp.jl")
include("wsospolyinterpmat.jl")
include("wsospolyinterpsoc.jl")

use_dual(cone::Cone) = cone.use_dual
load_point(cone::Cone{T}, point::AbstractVector{T}) where {T <: HypReal} = (cone.point = point)
dimension(cone::Cone) = cone.dim

function factorize_hess(cone::Cone)
    copyto!(cone.H2, cone.H)
    cone.F = hyp_chol!(Symmetric(cone.H2, :U))
    return isposdef(cone.F)
end

grad(cone::Cone) = cone.g
hess(cone::Cone) = Symmetric(cone.H, :U)
inv_hess(cone::Cone) = Symmetric(inv(cone.F), :U)
hess_fact(cone::Cone) = cone.F
hess_prod!(prod::AbstractVecOrMat{T}, arr::AbstractVecOrMat{T}, cone::Cone) where {T <: HypReal} = mul!(prod, Symmetric(cone.H, :U), arr)
inv_hess_prod!(prod::AbstractVecOrMat{T}, arr::AbstractVecOrMat{T}, cone::Cone) where {T <: HypReal} = ldiv!(prod, cone.F, arr)

# utilities for converting between smat and svec forms (lower triangle) for symmetric matrices
# TODO only need to do lower triangle if use symmetric matrix types

function smat_to_svec!(vec::AbstractVector{T}, mat::AbstractMatrix{T}) where {T <: HypReal}
    k = 1
    m = size(mat, 1)
    for i in 1:m, j in 1:i
        if i == j
            vec[k] = mat[i, j]
        else
            vec[k] = rt2 * mat[i, j]
        end
        k += 1
    end
    return vec
end

function svec_to_smat!(mat::AbstractMatrix{T}, vec::AbstractVector{T}) where {T <: HypReal}
    k = 1
    m = size(mat, 1)
    for i in 1:m, j in 1:i
        if i == j
            mat[i, j] = vec[k]
        else
            mat[i, j] = mat[j, i] = rt2i * vec[k]
        end
        k += 1
    end
    return mat
end

function smat_to_svec!(vec::AbstractVector{T}, mat::AbstractMatrix{Complex{T}}) where {T <: HypReal}
    k = 1
    m = size(mat, 1)
    for i in 1:m, j in 1:i
        if i == j
            vec[k] = mat[i, j]
            k += 1
        else
            ck = rt2 * mat[i, j]
            vec[k] = real(ck)
            k += 1
            vec[k] = imag(ck)
            k += 1
        end
    end
    return vec
end

function svec_to_smat!(mat::AbstractMatrix{Complex{T}}, vec::AbstractVector{T}) where {T <: HypReal}
    k = 1
    m = size(mat, 1)
    for i in 1:m, j in 1:i
        if i == j
            mat[i, j] = vec[k]
            k += 1
        else
            mat[i, j] = mat[j, i] = rt2i * Complex(vec[k], vec[k + 1])
            k += 2
        end
    end
    return mat
end

end