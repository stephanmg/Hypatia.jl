#=
Copyright 2018, Chris Coey and contributors

MathOptInterface wrapper of Hypatia solver
=#

mutable struct Optimizer <: MOI.AbstractOptimizer
    model::Model
    verbose::Bool
    timelimit::Float64
    linearsystem::Type{<:LinearSystems.LinearSystemSolver}
    usedense::Bool
    c::Vector{Float64}          # linear cost vector, size n
    A::AbstractMatrix{Float64}  # equality constraint matrix, size p*n
    b::Vector{Float64}          # equality constraint vector, size p
    G::AbstractMatrix{Float64}  # cone constraint matrix, size q*n
    h::Vector{Float64}          # cone constraint vector, size q
    cone::Cones.Cone                  # primal constraint cone object
    objsense::MOI.OptimizationSense
    objconst::Float64
    numeqconstrs::Int
    constroffseteq::Vector{Int}
    constrprimeq::Vector{Float64}
    constroffsetcone::Vector{Int}
    constrprimcone::Vector{Float64}
    intervalidxs
    intervalscales
    x::Vector{Float64}
    s::Vector{Float64}
    y::Vector{Float64}
    z::Vector{Float64}
    status::Symbol
    solvetime::Float64
    primal_obj::Float64
    dual_obj::Float64

    function Optimizer(model::Model, verbose::Bool, timelimit::Float64, linearsystem, usedense::Bool)
        opt = new()
        opt.model = model
        opt.verbose = verbose
        opt.timelimit = timelimit
        opt.linearsystem = linearsystem
        opt.usedense = usedense
        opt.status = :NotLoaded
        return opt
    end
end

Optimizer(;
    verbose::Bool = false,
    timelimit::Float64 = 3.6e3, # TODO should be Inf
    linearsystem = LinearSystems.QRSymm,
    usedense::Bool = true,
    tolrelopt::Float64 = 1e-6,
    tolabsopt::Float64 = 1e-7,
    tolfeas::Float64 = 1e-7,
    ) = Optimizer(Model(verbose=verbose, timelimit=timelimit, tolrelopt=tolrelopt, tolabsopt=tolabsopt, tolfeas=tolfeas), verbose, timelimit, linearsystem, usedense)

MOI.get(::Optimizer, ::MOI.SolverName) = "Hypatia"

MOI.is_empty(opt::Optimizer) = (opt.status == :NotLoaded)
MOI.empty!(opt::Optimizer) = (opt.status = :NotLoaded) # TODO empty the data and results? keep options?

MOI.supports(::Optimizer, ::Union{
    MOI.ObjectiveSense,
    MOI.ObjectiveFunction{MOI.SingleVariable},
    MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}},
    ) = true

# TODO don't restrict to Float64 type
SupportedFuns = Union{
    MOI.SingleVariable, MOI.ScalarAffineFunction{Float64},
    MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64},
    }

SupportedSets = Union{
    MOI.EqualTo{Float64}, MOI.Zeros,
    MOI.GreaterThan{Float64}, MOI.Nonnegatives,
    MOI.LessThan{Float64}, MOI.Nonpositives,
    MOI.Interval{Float64},
    MOIOtherCones...
    }

MOI.supports_constraint(::Optimizer, ::Type{<:SupportedFuns}, ::Type{<:SupportedSets}) = true

# build representation as min c'x s.t. A*x = b, h - G*x in K
function MOI.copy_to(
    opt::Optimizer,
    src::MOI.ModelLike;
    copy_names::Bool = false,
    warn_attributes::Bool = true,
    )
    @assert !copy_names
    idxmap = Dict{MOI.Index, MOI.Index}()

    # variables
    n = MOI.get(src, MOI.NumberOfVariables()) # columns of A
    j = 0
    for vj in MOI.get(src, MOI.ListOfVariableIndices()) # MOI.VariableIndex
        j += 1
        idxmap[vj] = MOI.VariableIndex(j)
    end
    @assert j == n

    # objective function
    F = MOI.get(src, MOI.ObjectiveFunctionType())
    if F == MOI.SingleVariable
        obj = MOI.ScalarAffineFunction{Float64}(MOI.get(src, MOI.ObjectiveFunction{F}()))
    elseif F == MOI.ScalarAffineFunction{Float64}
        obj = MOI.get(src, MOI.ObjectiveFunction{F}())
    end
    (Jc, Vc) = (Int[], Float64[])
    for t in obj.terms
        push!(Jc, idxmap[t.variable_index].value)
        push!(Vc, t.coefficient)
    end
    if MOI.get(src, MOI.ObjectiveSense()) == MOI.MAX_SENSE
        Vc .*= -1.0
    end
    opt.objconst = obj.constant
    opt.objsense = MOI.get(src, MOI.ObjectiveSense())
    opt.c = Vector(sparsevec(Jc, Vc, n))

    # constraints
    getsrccons(F, S) = MOI.get(src, MOI.ListOfConstraintIndices{F, S}())
    getconfun(conidx) = MOI.get(src, MOI.ConstraintFunction(), conidx)
    getconset(conidx) = MOI.get(src, MOI.ConstraintSet(), conidx)
    i = 0 # MOI constraint index

    # equality constraints
    p = 0 # rows of A (equality constraint matrix)
    (IA, JA, VA) = (Int[], Int[], Float64[])
    (Ib, Vb) = (Int[], Float64[])
    (Icpe, Vcpe) = (Int[], Float64[]) # constraint set constants for opt.constrprimeq
    constroffseteq = Vector{Int}()

    # TODO can preprocess variables equal to constant
    for ci in getsrccons(MOI.SingleVariable, MOI.EqualTo{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{Float64}}(i)
        push!(constroffseteq, p)
        p += 1
        push!(IA, p)
        push!(JA, idxmap[getconfun(ci).variable].value)
        push!(VA, -1.0)
        push!(Ib, p)
        push!(Vb, -getconset(ci).value)
        push!(Icpe, p)
        push!(Vcpe, getconset(ci).value)
    end

    for ci in getsrccons(MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}}(i)
        push!(constroffseteq, p)
        p += 1
        fi = getconfun(ci)
        for vt in fi.terms
            push!(IA, p)
            push!(JA, idxmap[vt.variable_index].value)
            push!(VA, -vt.coefficient)
        end
        push!(Ib, p)
        push!(Vb, fi.constant - getconset(ci).value)
        push!(Icpe, p)
        push!(Vcpe, getconset(ci).value)
    end

    # TODO can preprocess variables equal to zero here
    for ci in getsrccons(MOI.VectorOfVariables, MOI.Zeros)
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.Zeros}(i)
        push!(constroffseteq, p)
        fi = getconfun(ci)
        dim = MOI.output_dimension(fi)
        append!(IA, p+1:p+dim)
        append!(JA, idxmap[vi].value for vi in fi.variables)
        append!(VA, -ones(dim))
        p += dim
    end

    for ci in getsrccons(MOI.VectorAffineFunction{Float64}, MOI.Zeros)
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Zeros}(i)
        push!(constroffseteq, p)
        fi = getconfun(ci)
        dim = MOI.output_dimension(fi)
        for vt in fi.terms
            push!(IA, p + vt.output_index)
            push!(JA, idxmap[vt.scalar_term.variable_index].value)
            push!(VA, -vt.scalar_term.coefficient)
        end
        append!(Ib, p+1:p+dim)
        append!(Vb, fi.constants)
        p += dim
    end

    push!(constroffseteq, p)
    if opt.usedense
        opt.A = Matrix(sparse(IA, JA, VA, p, n))
    else
        opt.A = dropzeros!(sparse(IA, JA, VA, p, n))
    end
    opt.b = Vector(sparsevec(Ib, Vb, p)) # TODO if type less strongly, this can be sparse too
    opt.numeqconstrs = i
    opt.constrprimeq = Vector(sparsevec(Icpe, Vcpe, p))
    opt.constroffseteq = constroffseteq

    # conic constraints
    q = 0 # rows of G (cone constraint matrix)
    (IG, JG, VG) = (Int[], Int[], Float64[])
    (Ih, Vh) = (Int[], Float64[])
    (Icpc, Vcpc) = (Int[], Float64[]) # constraint set constants for opt.constrprimeq
    constroffsetcone = Vector{Int}()
    cone = Cones.Cone()

    # build up one nonnegative cone
    nonnegstart = q

    for ci in getsrccons(MOI.SingleVariable, MOI.GreaterThan{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{Float64}}(i)
        push!(constroffsetcone, q)
        q += 1
        push!(IG, q)
        push!(JG, idxmap[getconfun(ci).variable].value)
        push!(VG, -1.0)
        push!(Ih, q)
        push!(Vh, -getconset(ci).lower)
        push!(Vcpc, getconset(ci).lower)
        push!(Icpc, q)
    end

    for ci in getsrccons(MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}(i)
        push!(constroffsetcone, q)
        q += 1
        fi = getconfun(ci)
        for vt in fi.terms
            push!(IG, q)
            push!(JG, idxmap[vt.variable_index].value)
            push!(VG, -vt.coefficient)
        end
        push!(Ih, q)
        push!(Vh, fi.constant - getconset(ci).lower)
        push!(Vcpc, getconset(ci).lower)
        push!(Icpc, q)
    end

    for ci in getsrccons(MOI.VectorOfVariables, MOI.Nonnegatives)
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.Nonnegatives}(i)
        push!(constroffsetcone, q)
        for vj in getconfun(ci).variables
            q += 1
            push!(IG, q)
            push!(JG, idxmap[vj].value)
            push!(VG, -1.0)
        end
    end

    for ci in getsrccons(MOI.VectorAffineFunction{Float64}, MOI.Nonnegatives)
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Nonnegatives}(i)
        push!(constroffsetcone, q)
        fi = getconfun(ci)
        dim = MOI.output_dimension(fi)
        for vt in fi.terms
            push!(IG, q + vt.output_index)
            push!(JG, idxmap[vt.scalar_term.variable_index].value)
            push!(VG, -vt.scalar_term.coefficient)
        end
        append!(Ih, q+1:q+dim)
        append!(Vh, fi.constants)
        q += dim
    end

    if q > nonnegstart
        # exists at least one nonnegative constraint
        Cones.addCone!(cone, Cones.Nonnegative(q - nonnegstart), nonnegstart+1:q)
    end

    # build up one nonpositive cone
    nonposstart = q

    for ci in getsrccons(MOI.SingleVariable, MOI.LessThan{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{Float64}}(i)
        push!(constroffsetcone, q)
        q += 1
        push!(IG, q)
        push!(JG, idxmap[getconfun(ci).variable].value)
        push!(VG, -1.0)
        push!(Ih, q)
        push!(Vh, -getconset(ci).upper)
        push!(Vcpc, getconset(ci).upper)
        push!(Icpc, q)
    end

    for ci in getsrccons(MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}(i)
        push!(constroffsetcone, q)
        q += 1
        fi = getconfun(ci)
        for vt in fi.terms
            push!(IG, q)
            push!(JG, idxmap[vt.variable_index].value)
            push!(VG, -vt.coefficient)
        end
        push!(Ih, q)
        push!(Vh, fi.constant - getconset(ci).upper)
        push!(Vcpc, getconset(ci).upper)
        push!(Icpc, q)
    end

    for ci in getsrccons(MOI.VectorOfVariables, MOI.Nonpositives)
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.VectorOfVariables, MOI.Nonpositives}(i)
        push!(constroffsetcone, q)
        for vj in getconfun(ci).variables
            q += 1
            push!(IG, q)
            push!(JG, idxmap[vj].value)
            push!(VG, -1.0)
        end
    end

    for ci in getsrccons(MOI.VectorAffineFunction{Float64}, MOI.Nonpositives)
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.VectorAffineFunction{Float64}, MOI.Nonpositives}(i)
        push!(constroffsetcone, q)
        fi = getconfun(ci)
        dim = MOI.output_dimension(fi)
        for vt in fi.terms
            push!(IG, q + vt.output_index)
            push!(JG, idxmap[vt.scalar_term.variable_index].value)
            push!(VG, -vt.scalar_term.coefficient)
        end
        append!(Ih, q+1:q+dim)
        append!(Vh, fi.constants)
        q += dim
    end

    if q > nonposstart
        # exists at least one nonpositive constraint
        Cones.addCone!(cone, Cones.Nonpositive(q - nonposstart), nonposstart+1:q)
    end

    # build up one L_infinity norm cone from two-sided interval constraints
    intervalstart = q
    nintervals = MOI.get(src, MOI.NumberOfConstraints{MOI.SingleVariable, MOI.Interval{Float64}}()) + MOI.get(src, MOI.NumberOfConstraints{MOI.ScalarAffineFunction{Float64}, MOI.Interval{Float64}}())
    intervalscales = Vector{Float64}(undef, nintervals)

    if nintervals > 0
        i += 1
        push!(constroffsetcone, q)
        q += 1
        push!(Ih, q)
        push!(Vh, 1.0)
    end

    intervalcount = 0

    for ci in getsrccons(MOI.SingleVariable, MOI.Interval{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.SingleVariable, MOI.Interval{Float64}}(i)
        push!(constroffsetcone, q)
        q += 1

        upper = getconset(ci).upper
        lower = getconset(ci).lower
        @assert isfinite(upper) && isfinite(lower)
        @assert upper > lower
        mid = 0.5*(upper + lower)
        scal = 2.0*inv(upper - lower)

        push!(IG, q)
        push!(JG, idxmap[getconfun(ci).variable].value)
        push!(VG, -scal)
        push!(Ih, q)
        push!(Vh, -mid*scal)
        push!(Vcpc, mid)
        push!(Icpc, q)
        intervalcount += 1
        intervalscales[intervalcount] = scal
    end

    for ci in getsrccons(MOI.ScalarAffineFunction{Float64}, MOI.Interval{Float64})
        i += 1
        idxmap[ci] = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.Interval{Float64}}(i)
        push!(constroffsetcone, q)
        q += 1

        upper = getconset(ci).upper
        lower = getconset(ci).lower
        @assert isfinite(upper) && isfinite(lower)
        @assert upper > lower
        mid = 0.5*(upper + lower)
        scal = 2.0/(upper - lower)

        fi = getconfun(ci)
        for vt in fi.terms
            push!(IG, q)
            push!(JG, idxmap[vt.variable_index].value)
            push!(VG, -vt.coefficient*scal)
        end
        push!(Ih, q)
        push!(Vh, (fi.constant - mid)*scal)
        push!(Vcpc, mid)
        push!(Icpc, q)
        intervalcount += 1
        intervalscales[intervalcount] = scal
    end

    opt.intervalidxs = intervalstart+2:q
    opt.intervalscales = intervalscales
    if q > intervalstart
        # exists at least one interval-type constraint
        Cones.addCone!(cone, Cones.EpiNormInf(q - intervalstart), intervalstart+1:q)
    end

    # add non-LP conic constraints

    for S in MOIOtherCones, F in (MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64})
        for ci in getsrccons(F, S)
            i += 1
            idxmap[ci] = MOI.ConstraintIndex{F, S}(i)
            push!(constroffsetcone, q)
            fi = getconfun(ci)
            si = getconset(ci)
            dim = MOI.output_dimension(fi)
            if F == MOI.VectorOfVariables
                append!(JG, idxmap[vj].value for vj in fi.variables)
                (IGi, VGi, conei) = buildvarcone(fi, si, dim, q)
            else
                append!(JG, idxmap[vt.scalar_term.variable_index].value for vt in fi.terms)
                (IGi, VGi, Ihi, Vhi, conei) = buildconstrcone(fi, si, dim, q)
                append!(Ih, Ihi)
                append!(Vh, Vhi)
            end
            append!(IG, IGi)
            append!(VG, VGi)
            Cones.addCone!(cone, conei, q+1:q+dim)
            q += dim
        end
    end

    push!(constroffsetcone, q)
    if opt.usedense
        opt.G = Matrix(sparse(IG, JG, VG, q, n))
    else
        opt.G = dropzeros!(sparse(IG, JG, VG, q, n))
    end
    opt.h = Vector(sparsevec(Ih, Vh, q))
    opt.cone = cone
    opt.constroffsetcone = constroffsetcone
    opt.constrprimcone = Vector(sparsevec(Icpc, Vcpc, q))
    opt.status = :Loaded

    return idxmap
end

function MOI.optimize!(opt::Optimizer)
    model = opt.model
    (c, A, b, G, h, cone) = (opt.c, opt.A, opt.b, opt.G, opt.h, opt.cone)

    # check, preprocess, load, and solve
    check_data(c, A, b, G, h, cone)
    if opt.linearsystem == LinearSystems.QRSymm
        (c1, A1, b1, G1, prkeep, dukeep, Q2, RiQ1) = preprocess_data(c, A, b, G, useQR=true)
        L = LinearSystems.QRSymm(c1, A1, b1, G1, h, cone, Q2, RiQ1)
    elseif opt.linearsystem == LinearSystems.Naive
        (c1, A1, b1, G1, prkeep, dukeep, Q2, RiQ1) = preprocess_data(c, A, b, G, useQR=false)
        L = LinearSystems.Naive(c1, A1, b1, G1, h, cone)
    else
        error("linear system cache type $(opt.linearsystem) is not recognized")
    end
    load_data!(model, c1, A1, b1, G1, h, cone, L)
    solve!(model)

    opt.status = get_status(model)
    opt.solvetime = get_solve_time(model)
    opt.primal_obj = get_primal_obj(model)
    opt.dual_obj = get_dual_obj(model)

    # get solution and transform for MOI
    opt.x = zeros(length(c))
    opt.x[dukeep] = get_x(model)
    opt.constrprimeq += opt.b - opt.A*opt.x
    opt.y = zeros(length(b))
    opt.y[prkeep] = get_y(model)

    opt.s = get_s(model)
    opt.z = get_z(model)

    # TODO refac out primitive cone untransformations
    for k in eachindex(cone.cones)
        if cone.cones[k] isa Cones.PosSemidef
            idxs = cone.idxs[k]
            scalevec = svecunscale(length(idxs))
            opt.s[idxs] .*= scalevec
            opt.z[idxs] .*= scalevec
        elseif cone.cones[k] isa Cones.HypoPerLogdet
            idxs = cone.idxs[k][3:end]
            scalevec = svecunscale(length(idxs))
            opt.s[idxs] .*= scalevec
            opt.z[idxs] .*= scalevec
        end
    end

    opt.s[opt.intervalidxs] ./= opt.intervalscales
    opt.constrprimcone += opt.s
    opt.z[opt.intervalidxs] .*= opt.intervalscales

    return
end

# function MOI.free!(opt::Optimizer) # TODO call gc on opt.model?

function MOI.get(opt::Optimizer, ::MOI.TerminationStatus)
    if opt.status in (:NotLoaded, :Loaded)
        return MOI.OPTIMIZE_NOT_CALLED
    elseif opt.status == :Optimal
        return MOI.OPTIMAL
    elseif opt.status == :PrimalInfeasible
        return MOI.INFEASIBLE
    elseif opt.status == :DualInfeasible
        return MOI.DUAL_INFEASIBLE
    elseif opt.status == :IllPosed
        error("MOI did not have a TerminationStatusCode for ill-posed")
    elseif opt.status in (:PredictorFail, :CorrectorFail)
        return MOI.SLOW_PROGRESS
    elseif opt.status == :IterationLimit
        return MOI.ITERATION_LIMIT
    elseif opt.status == :TimeLimit
        return MOI.TIME_LIMIT
    else
        @warn("Hypatia status $(opt.status) not handled")
        return MOI.OTHER_ERROR
    end
end

function MOI.get(opt::Optimizer, ::MOI.ObjectiveValue)
    if opt.objsense == MOI.MIN_SENSE
        return opt.primal_obj + opt.objconst
    elseif opt.objsense == MOI.MAX_SENSE
        return -opt.primal_obj + opt.objconst
    else
        error("no objective sense is set")
    end
end

function MOI.get(opt::Optimizer, ::MOI.ObjectiveBound)
    if opt.objsense == MOI.MIN_SENSE
        return opt.dual_obj + opt.objconst
    elseif opt.objsense == MOI.MAX_SENSE
        return -opt.dual_obj + opt.objconst
    else
        error("no objective sense is set")
    end
end

function MOI.get(opt::Optimizer, ::MOI.ResultCount)
    if opt.status in (:Optimal, :PrimalInfeasible, :DualInfeasible, :IllPosed)
        return 1
    end
    return 0
end

function MOI.get(opt::Optimizer, ::MOI.PrimalStatus)
    if opt.status == :Optimal
        return MOI.FEASIBLE_POINT
    elseif opt.status == :PrimalInfeasible
        return MOI.INFEASIBLE_POINT
    elseif opt.status == :DualInfeasible
        return MOI.INFEASIBILITY_CERTIFICATE
    elseif opt.status == :IllPosed
        return MOI.OTHER_RESULT_STATUS # TODO later distinguish primal/dual ill posed certificates
    else
        return MOI.UNKNOWN_RESULT_STATUS
    end
end

function MOI.get(opt::Optimizer, ::MOI.DualStatus)
    if opt.status == :Optimal
        return MOI.FEASIBLE_POINT
    elseif opt.status == :PrimalInfeasible
        return MOI.INFEASIBILITY_CERTIFICATE
    elseif opt.status == :DualInfeasible
        return MOI.INFEASIBLE_POINT
    elseif opt.status == :IllPosed
        return MOI.OTHER_RESULT_STATUS # TODO later distinguish primal/dual ill posed certificates
    else
        return MOI.UNKNOWN_RESULT_STATUS
    end
end

MOI.get(opt::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex) = opt.x[vi.value]
MOI.get(opt::Optimizer, a::MOI.VariablePrimal, vi::Vector{MOI.VariableIndex}) = MOI.get.(opt, a, vi)

function MOI.get(opt::Optimizer, ::MOI.ConstraintDual, ci::MOI.ConstraintIndex{F, S}) where {F <: MOI.AbstractFunction, S <: MOI.AbstractScalarSet}
    # scalar set
    i = ci.value
    if i <= opt.numeqconstrs
        # constraint is an equality
        return opt.y[opt.constroffseteq[i]+1]
    else
        # constraint is conic
        i -= opt.numeqconstrs
        return opt.z[opt.constroffsetcone[i]+1]
    end
end
function MOI.get(opt::Optimizer, ::MOI.ConstraintDual, ci::MOI.ConstraintIndex{F, S}) where {F <: MOI.AbstractFunction, S <: MOI.AbstractVectorSet}
    # vector set
    i = ci.value
    if i <= opt.numeqconstrs
        # constraint is an equality
        os = opt.constroffseteq
        return opt.y[os[i]+1:os[i+1]]
    else
        # constraint is conic
        i -= opt.numeqconstrs
        os = opt.constroffsetcone
        return opt.z[os[i]+1:os[i+1]]
    end
end
MOI.get(opt::Optimizer, a::MOI.ConstraintDual, ci::Vector{MOI.ConstraintIndex}) = MOI.get.(opt, a, ci)

function MOI.get(opt::Optimizer, ::MOI.ConstraintPrimal, ci::MOI.ConstraintIndex{F, S}) where {F <: MOI.AbstractFunction, S <: MOI.AbstractScalarSet}
    # scalar set
    i = ci.value
    if i <= opt.numeqconstrs
        # constraint is an equality
        return opt.constrprimeq[opt.constroffseteq[i]+1]
    else
        # constraint is conic
        i -= opt.numeqconstrs
        return opt.constrprimcone[opt.constroffsetcone[i]+1]
    end
end
function MOI.get(opt::Optimizer, ::MOI.ConstraintPrimal, ci::MOI.ConstraintIndex{F, S}) where {F <: MOI.AbstractFunction, S <: MOI.AbstractVectorSet}
    # vector set
    i = ci.value
    if i <= opt.numeqconstrs
        # constraint is an equality
        os = opt.constroffseteq
        return opt.constrprimeq[os[i]+1:os[i+1]]
    else
        # constraint is conic
        i -= opt.numeqconstrs
        os = opt.constroffsetcone
        return opt.constrprimcone[os[i]+1:os[i+1]]
    end
end
MOI.get(opt::Optimizer, a::MOI.ConstraintPrimal, ci::Vector{MOI.ConstraintIndex}) = MOI.get.(opt, a, ci)
