#=
interpolation-based weighted-sum-of-squares (multivariate) polynomial cone parametrized by interpolation matrices Ps

definition and dual barrier from "Sum-of-squares optimization without semidefinite programming" by D. Papp and S. Yildiz, available at https://arxiv.org/abs/1712.01792

TODO
in complex case, can maybe compute Lambda fast in feas check by taking sqrt of point and doing outer product
=#

mutable struct WSOSInterpNonnegative{T <: Real, R <: RealOrComplex{T}} <: Cone{T}
    use_dual_barrier::Bool
    use_heuristic_neighborhood::Bool
    dim::Int
    Ps::Vector{Matrix{R}}

    point::Vector{T}
    dual_point::Vector{T}
    grad::Vector{T}
    correction::Vector{T}
    vec1::Vector{T}
    vec2::Vector{T}
    feas_updated::Bool
    grad_updated::Bool
    hess_updated::Bool
    inv_hess_updated::Bool
    hess_fact_updated::Bool
    is_feas::Bool
    hess::Symmetric{T, Matrix{T}}
    inv_hess::Symmetric{T, Matrix{T}}
    hess_fact_cache

    tempLL::Vector{Matrix{R}}
    tempLL2::Vector{Matrix{R}}
    tempUL::Vector{Matrix{R}}
    ΛFLP::Vector{Matrix{R}}
    # tempLU2::Vector{Matrix{R}}
    tempUU::Matrix{R}
    ΛF::Vector
    Ps_times::Vector{Float64}
    Ps_order::Vector{Int}

    function WSOSInterpNonnegative{T, R}(
        U::Int,
        Ps::Vector{Matrix{R}};
        use_dual::Bool = false,
        use_heuristic_neighborhood::Bool = default_use_heuristic_neighborhood(),
        hess_fact_cache = hessian_cache(T),
        ) where {R <: RealOrComplex{T}} where {T <: Real}
        for Pk in Ps
            @assert size(Pk, 1) == U
        end
        cone = new{T, R}()
        cone.use_dual_barrier = !use_dual # using dual barrier
        cone.use_heuristic_neighborhood = use_heuristic_neighborhood
        cone.dim = U
        cone.Ps = Ps
        cone.hess_fact_cache = hess_fact_cache
        return cone
    end
end

function setup_extra_data(cone::WSOSInterpNonnegative{T, R}) where {R <: RealOrComplex{T}} where {T <: Real}
    dim = cone.dim
    cone.hess = Symmetric(zeros(T, dim, dim), :U)
    cone.inv_hess = Symmetric(zeros(T, dim, dim), :U)
    load_matrix(cone.hess_fact_cache, cone.hess)
    Ls = [size(Pk, 2) for Pk in cone.Ps]
    cone.tempLL = [zeros(R, L, L) for L in Ls]
    cone.tempLL2 = [zeros(R, L, L) for L in Ls]
    cone.tempUL = [zeros(R, dim, L) for L in Ls]
    cone.ΛFLP = [zeros(R, L, dim) for L in Ls]
    # cone.tempLU2 = [zeros(R, L, dim) for L in Ls]
    cone.tempUU = zeros(R, dim, dim)
    K = length(Ls)
    cone.ΛF = Vector{Any}(undef, K)
    cone.Ps_times = zeros(K)
    cone.Ps_order = collect(1:K)
    return cone
end

get_nu(cone::WSOSInterpNonnegative) = sum(size(Pk, 2) for Pk in cone.Ps)

set_initial_point(arr::AbstractVector, cone::WSOSInterpNonnegative) = (arr .= 1)

function update_feas(cone::WSOSInterpNonnegative)
    @assert !cone.feas_updated
    D = Diagonal(cone.point)

    # order the Ps by how long it takes to check feasibility, to improve efficiency
    sortperm!(cone.Ps_order, cone.Ps_times, initialized = true) # NOTE stochastic

    cone.is_feas = true
    for k in cone.Ps_order
        cone.Ps_times[k] = @elapsed @inbounds begin
            # Λ = Pk' * Diagonal(point) * Pk
            # TODO mul!(A, B', Diagonal(x)) calls inefficient method but doesn't need ULk
            Pk = cone.Ps[k]
            ULk = cone.tempUL[k]
            LLk = cone.tempLL[k]
            mul!(ULk, D, Pk)
            mul!(LLk, Pk', ULk)

            ΛFk = cone.ΛF[k] = cholesky!(Hermitian(LLk, :L), check = false)
            if !isposdef(ΛFk)
                cone.is_feas = false
                break
            end
        end
    end

    cone.feas_updated = true
    return cone.is_feas
end

is_dual_feas(cone::WSOSInterpNonnegative) = true

function update_grad(cone::WSOSInterpNonnegative)
    @assert cone.is_feas

    cone.grad .= 0
    @inbounds for k in eachindex(cone.Ps)
        ΛFLPk = cone.ΛFLP[k] # computed here
        ldiv!(ΛFLPk, cone.ΛF[k].L, cone.Ps[k]')
        @views for j in 1:cone.dim
            cone.grad[j] -= sum(abs2, ΛFLPk[:, j])
        end
    end

    cone.grad_updated = true
    return cone.grad
end

function update_hess(cone::WSOSInterpNonnegative)
    @assert cone.grad_updated
    UU = cone.tempUU

    cone.hess .= 0
    @inbounds for k in eachindex(cone.Ps)
        outer_prod(cone.ΛFLP[k], UU, true, false)
        for j in 1:cone.dim, i in 1:j
            cone.hess.data[i, j] += abs2(UU[i, j])
        end
    end

    cone.hess_updated = true
    return cone.hess
end

function hess_prod!(prod::AbstractVecOrMat, arr::AbstractVecOrMat, cone::WSOSInterpNonnegative)
    @assert is_feas(cone)
    prod .= 0

    @inbounds for k in eachindex(cone.Ps)
        Pk = cone.Ps[k]
        ΛFk = cone.ΛF[k]
        ULk = cone.tempUL[k]
        LLk = cone.tempLL2[k]
        # LUk = cone.tempLU2[k]
        ΛFLPk = cone.ΛFLP[k]

        # @views for j in 1:size(arr, 2)
        #     mul!(ULk, Diagonal(arr[:, j]), ΛFLPk')
        #     mul!(LLk, ΛFLPk, ULk)
        #     mul!(LUk, LLk, ΛFLPk)
        #     for i in 1:cone.dim
        #         prod[i, j] += real(dot(ΛFLPk[:, i], LUk[:, i]))
        #     end
        # end

        @views for j in 1:size(arr, 2)
            mul!(ULk, Diagonal(arr[:, j]), ΛFLPk')
            mul!(LLk, ΛFLPk, ULk)
            HLLk = Hermitian(LLk)
            for i in 1:cone.dim
                ΛFLPki = ΛFLPk[:, i]
                prod[i, j] += real(dot(ΛFLPki, HLLk, ΛFLPki))
            end
        end

        # @views for j in 1:size(arr, 2)
        #     mul!(ULk, Diagonal(arr[:, j]), Pk)
        #     mul!(LLk, Pk', ULk)
        #     ldiv!(ΛFk, LLk)
        #     rdiv!(LLk, ΛFk)
        #     mul!(LUk, LLk, Pk')
        #     @views for i in 1:cone.dim
        #         prod[i, j] += dot(Pk[i, :], LUk[:, i])
        #     end
        # end
    end

    return prod
end

function correction(cone::WSOSInterpNonnegative, primal_dir::AbstractVector)
    corr = cone.correction
    corr .= 0

    @inbounds for k in eachindex(cone.Ps)
        Pk = cone.Ps[k]
        ΛFk = cone.ΛF[k]
        ULk = cone.tempUL[k]
        LLk = cone.tempLL2[k]
        # LUk = cone.tempLU2[k]
        ΛFLPk = cone.ΛFLP[k]
        D = Diagonal(primal_dir)

        mul!(ULk, D, ΛFLPk')
        mul!(LLk, ΛFLPk, ULk)
        mul!(ULk, ΛFLPk', Hermitian(LLk))
        @views for j in 1:cone.dim
            corr[j] += sum(abs2, ULk[j, :])
        end

        # mul!(ULk, D, Pk)
        # mul!(LLk, Pk', ULk)
        # ldiv!(ΛFk.L, LLk)
        # rdiv!(LLk, ΛFk)
        # mul!(LUk, LLk, Pk')
        # for j in 1:cone.dim
        #     @views corr[j] += sum(abs2, LUk[:, j])
        # end
    end

    return corr
end
