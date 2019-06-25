#=
Copyright 2018, Chris Coey and contributors

(closure of) hypograph of perspective of (natural) log of determinant of a (row-wise lower triangle i.e. svec space) symmetric positive define matrix
(smat space) (u in R, v in R_+, w in S_+) : u <= v*logdet(W/v)
(see equivalent MathOptInterface LogDetConeConeTriangle definition)

barrier (guessed, based on analogy to hypoperlog barrier)
-log(v*logdet(W/v) - u) - logdet(W) - log(v)

TODO remove allocations
=#

mutable struct HypoPerLogdet{T <: HypReal} <: Cone{T}
    use_dual::Bool
    dim::Int
    side::Int

    point::AbstractVector{T}
    mat::Matrix{T}
    g::Vector{T}
    H::Matrix{T}
    H2::Matrix{T}
    F

    function HypoPerLogdet{T}(dim::Int, is_dual::Bool) where {T <: HypReal}
        cone = new{T}()
        cone.use_dual = is_dual
        cone.dim = dim
        cone.side = round(Int, sqrt(0.25 + 2 * (dim - 2)) - 0.5)
        return cone
    end
end

HypoPerLogdet{T}(dim::Int) where {T <: HypReal} = HypoPerLogdet{T}(dim, false)

function setup_data(cone::HypoPerLogdet{T}) where {T <: HypReal}
    dim = cone.dim
    side = round(Int, sqrt(0.25 + 2 * (dim - 2)) - 0.5)
    side = cone.side
    cone.mat = Matrix{T}(undef, side, side)
    cone.g = Vector{T}(undef, dim)
    cone.H = zeros(T, dim, dim)
    cone.H2 = similar(cone.H)
    return
end

get_nu(cone::HypoPerLogdet) = cone.side + 2

function set_initial_point(arr::AbstractVector{T}, cone::HypoPerLogdet{T}) where {T <: HypReal}
    arr[1] = -one(T)
    arr[2] = one(T)
    smat_to_svec!(view(arr, 3:cone.dim), Matrix(one(T) * I, cone.side, cone.side)) # TODO remove allocs
    return arr
end

# TODO remove allocs
function check_in_cone(cone::HypoPerLogdet{T}) where {T <: HypReal}
    u = cone.point[1]
    v = cone.point[2]
    if v <= zero(T)
        return false
    end
    W = cone.mat
    svec_to_smat!(W, view(cone.point, 3:cone.dim))
    F = hyp_chol!(Symmetric(W))
    ldW = logdet(F)
    if !isposdef(F) || u >= v * (ldW - cone.side * log(v))
        return false
    end

    # L = logdet(W / v)
    L = ldW - cone.side * log(v)
    z = v * L - u

    Wi = Symmetric(inv(F))
    n = cone.side
    dim = cone.dim
    vzi = v / z

    cone.g[1] = inv(z)
    cone.g[2] = (T(n) - L) / z - inv(v)
    gwmat = -Wi * (one(T) + vzi)
    smat_to_svec!(view(cone.g, 3:dim), gwmat)

    cone.H[1, 1] = inv(z) / z
    cone.H[1, 2] = (T(n) - L) / z / z
    Huwmat = -vzi * Wi / z
    smat_to_svec!(view(cone.H, 1, 3:dim), Huwmat)

    cone.H[2, 2] = abs2(T(-n) + L) / z / z + T(n) / (v * z) + inv(v) / v
    Hvwmat = ((T(-n) + L) * vzi - one(T)) * Wi / z
    smat_to_svec!(view(cone.H, 2, 3:dim), Hvwmat)

    k = 3
    for i in 1:n, j in 1:i
        k2 = 3
        for i2 in 1:n, j2 in 1:i2
            if (i == j) && (i2 == j2)
                cone.H[k2, k] = abs2(Wi[i2, i]) * (vzi + one(T)) + Wi[i, i] * Wi[i2, i2] * abs2(vzi)
            elseif (i != j) && (i2 != j2)
                cone.H[k2, k] = (Wi[i2, i] * Wi[j, j2] + Wi[j2, i] * Wi[j, i2]) * (vzi + one(T)) + 2 * Wi[i, j] * Wi[i2, j2] * abs2(vzi)
            else
                cone.H[k2, k] = rt2 * (Wi[i2, i] * Wi[j, j2] * (vzi + one(T)) + Wi[i, j] * Wi[i2, j2] * abs2(vzi))
            end
            if k2 == k
                break
            end
            k2 += 1
        end
        k += 1
    end

    return factorize_hess(cone)
end