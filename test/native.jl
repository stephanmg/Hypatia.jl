#=
Copyright 2018, Chris Coey and contributors
=#

function solveandcheck(model::MO.Model, solver::IP.IPMSolver; atol=1e-4, rtol=1e-4)
    IP.solve(solver)

    x = IP.get_x(solver)
    y = IP.get_y(solver)
    s = IP.get_s(solver)
    z = IP.get_z(solver)
    primal_obj = IP.get_primal_obj(solver)
    dual_obj = IP.get_dual_obj(solver)
    status = IP.get_status(solver)
    solve_time = IP.get_solve_time(solver)
    num_iters = IP.get_num_iters(solver)

    # check conic certificates are valid
    (c, A, b, G, h) = (model.c, model.A, model.b, model.G, model.h)
    if status == :Optimal
        @test primal_obj ≈ dual_obj atol=atol rtol=rtol
        @test A * x ≈ b atol=atol rtol=rtol
        @test G * x + s ≈ h atol=atol rtol=rtol
        @test G' * z + A' * y ≈ -c atol=atol rtol=rtol
        @test dot(s, z) ≈ 0.0 atol=atol rtol=rtol
        @test dot(c, x) ≈ primal_obj atol=1e-8 rtol=1e-8
        @test dot(b, y) + dot(h, z) ≈ -dual_obj atol=1e-8 rtol=1e-8
    elseif status == :PrimalInfeasible
        @test isnan(primal_obj)
        @test dual_obj > 0
        @test dot(b, y) + dot(h, z) ≈ -dual_obj atol=1e-8 rtol=1e-8
        @test G' * z ≈ -A' * y atol=atol rtol=rtol
    elseif status == :DualInfeasible
        @test isnan(dual_obj)
        @test primal_obj < 0
        @test dot(c, x) ≈ primal_obj atol=1e-8 rtol=1e-8
        @test G * x ≈ -s atol=atol rtol=rtol
        @test A * x ≈ zeros(length(y)) atol=atol rtol=rtol
    elseif status == :IllPosed
        # TODO primal vs dual ill-posed statuses and conditions
    end

    return (x=x, y=y, s=s, z=z, primal_obj=primal_obj, dual_obj=dual_obj, status=status, solve_time=solve_time, num_iters=num_iters)
end

function dimension1(; verbose::Bool = true)
    c = [-1, 0]
    A = Matrix{Float64}(undef, 0, 2)
    b = Float64[]
    G = [1 0]
    h = [1]
    cones = [CO.Nonnegative(1, false)]
    cone_idxs = [1:1]
    model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)

    for use_sparse in (true, false)
        if use_sparse
            model.A = sparse(A)
            model.G = sparse(G)
        end

        r = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
        r.status == :Optimal
        @test r.primal_obj ≈ -1 atol=1e-4 rtol=1e-4
        @test r.x ≈ [1, 0] atol=1e-4 rtol=1e-4
        @test isempty(r.y)

        # TODO
        # model.c = [-1.0, -1.0]
        # @test_throws ErrorException("some dual equality constraints are inconsistent") HYP.preprocess_data(c, A, b, G, useQR=true)
    end
end

# function consistent1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     Random.seed!(1)
#     (n, p, q) = (30, 15, 30)
#     A = rand(-9.0:9.0, p, n)
#     G = Matrix(1.0I, q, n)
#     c = rand(0.0:9.0, n)
#     rnd1 = rand()
#     rnd2 = rand()
#     A[11:15,:] = rnd1*A[1:5,:] - rnd2*A[6:10,:]
#     b = A*ones(n)
#     rnd1 = rand()
#     rnd2 = rand()
#     A[:,11:15] = rnd1*A[:,1:5] - rnd2*A[:,6:10]
#     G[:,11:15] = rnd1*G[:,1:5] - rnd2*G[:,6:10]
#     c[11:15] = rnd1*c[1:5] - rnd2*c[6:10]
#     h = zeros(q)
#     cone = CO.Cone([CO.Nonpositive(q)], [1:q])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
# end
#
# function inconsistent1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     Random.seed!(1)
#     (n, p, q) = (30, 15, 30)
#     A = rand(-9.0:9.0, p, n)
#     G = Matrix(-1.0I, q, n)
#     c = rand(0.0:9.0, n)
#     b = rand(p)
#     rnd1 = rand()
#     rnd2 = rand()
#     A[11:15,:] = rnd1*A[1:5,:] - rnd2*A[6:10,:]
#     b[11:15] = 2*(rnd1*b[1:5] - rnd2*b[6:10])
#     h = zeros(q)
#     cone = CO.Cone([CO.Nonnegative(q)], [1:q])
#     @test_throws ErrorException("some primal equality constraints are inconsistent") solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
# end
#
# function inconsistent2(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     Random.seed!(1)
#     (n, p, q) = (30, 15, 30)
#     A = rand(-9.0:9.0, p, n)
#     G = Matrix(-1.0I, q, n)
#     c = rand(0.0:9.0, n)
#     b = rand(p)
#     rnd1 = rand()
#     rnd2 = rand()
#     A[:,11:15] = rnd1*A[:,1:5] - rnd2*A[:,6:10]
#     G[:,11:15] = rnd1*G[:,1:5] - rnd2*G[:,6:10]
#     c[11:15] = 2*(rnd1*c[1:5] - rnd2*c[6:10])
#     h = zeros(q)
#     cone = CO.Cone([CO.Nonnegative(q)], [1:q])
#     @test_throws ErrorException("some dual equality constraints are inconsistent") solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
# end

function orthant1(; verbose::Bool = true)
    Random.seed!(1)
    (n, p, q) = (6, 3, 6)
    c = rand(0.0:9.0, n)
    A = rand(-9.0:9.0, p, n)
    b = A * ones(n)
    h = zeros(q)
    cone_idxs = [1:q]

    # nonnegative cone
    model = MO.LinearObjConic(c, A, b, SparseMatrixCSC(-1.0I, q, n), h, [CO.Nonnegative(q)], cone_idxs)
    rnn = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test rnn.status == :Optimal

    # nonpositive cone
    model = MO.LinearObjConic(c, A, b, SparseMatrixCSC(1.0I, q, n), h, [CO.Nonpositive(q)], cone_idxs)
    rnp = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test rnp.status == :Optimal

    @test rnp.primal_obj ≈ rnn.primal_obj atol=1e-4 rtol=1e-4
end

function orthant2(; verbose::Bool = true)
    Random.seed!(1)
    (n, p, q) = (5, 2, 10)
    c = rand(0.0:9.0, n)
    A = rand(-9.0:9.0, p, n)
    b = A * ones(n)
    G = rand(q, n) - Matrix(2.0I, q, n)
    h = G * ones(n)
    cone_idxs = [1:q]

    # use dual barrier
    model = MO.LinearObjConic(c, A, b, G, h, [CO.Nonnegative(q, true)], cone_idxs)
    r1 = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test r1.status == :Optimal

    # use primal barrier
    model = MO.LinearObjConic(c, A, b, G, h, [CO.Nonnegative(q, false)], cone_idxs)
    r2 = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test r2.status == :Optimal

    @test r1.primal_obj ≈ r2.primal_obj atol=1e-4 rtol=1e-4
end

function orthant3(; verbose::Bool = true)
    Random.seed!(1)
    (n, p, q) = (15, 6, 15)
    c = rand(0.0:9.0, n)
    A = rand(-9.0:9.0, p, n)
    b = A * ones(n)
    G = Diagonal(1.0I, n)
    h = zeros(q)
    cone_idxs = [1:q]

    # use dual barrier
    model = MO.LinearObjConic(c, A, b, G, h, [CO.Nonpositive(q, true)], cone_idxs)
    r1 = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test r1.status == :Optimal

    # use primal barrier
    model = MO.LinearObjConic(c, A, b, G, h, [CO.Nonpositive(q, false)], cone_idxs)
    r2 = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test r2.status == :Optimal

    @test r1.primal_obj ≈ r2.primal_obj atol=1e-4 rtol=1e-4
end

function orthant4(; verbose::Bool = true)
    Random.seed!(1)
    (n, p, q) = (5, 2, 10)
    c = rand(0.0:9.0, n)
    A = rand(-9.0:9.0, p, n)
    b = A * ones(n)
    G = rand(q, n) - Matrix(2.0I, q, n)
    h = G * ones(n)

    # mixture of nonnegative and nonpositive cones
    model = MO.LinearObjConic(c, A, b, G, h, [CO.Nonnegative(4, false), CO.Nonnegative(6, true)], [1:4, 5:10])
    r1 = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test r1.status == :Optimal

    # only nonnegative cone
    model = MO.LinearObjConic(c, A, b, G, h, [CO.Nonnegative(10, false)], [1:10])
    r2 = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
    @test r2.status == :Optimal

    @test r1.primal_obj ≈ r2.primal_obj atol=1e-4 rtol=1e-4
end
#
# function epinorminf1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[0, -1, -1]
#     A = Float64[1 0 0; 0 1 0]
#     b = Float64[1, 1/sqrt(2)]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#     cone = CO.Cone([CO.EpiNormInf(3)], [1:3])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ -1 - 1/sqrt(2) atol=1e-4 rtol=1e-4
#     @test r.x ≈ [1, 1/sqrt(2), 1] atol=1e-4 rtol=1e-4
#     @test r.y ≈ [1, 1] atol=1e-4 rtol=1e-4
# end
#
# function epinorminf2(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     Random.seed!(1)
#     c = Float64[1, 0, 0, 0, 0, 0]
#     A = rand(-9.0:9.0, 3, 6)
#     b = A*ones(6)
#     G = rand(6, 6)
#     h = G*ones(6)
#     cone = CO.Cone([CO.EpiNormInf(6)], [1:6])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ 1 atol=1e-4 rtol=1e-4
# end
#
# function epinorminf3(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     Random.seed!(1)
#     c = Float64[1, 0, 0, 0, 0, 0]
#     A = zeros(0, 6)
#     b = zeros(0)
#     G = SparseMatrixCSC(-1.0I, 6, 6)
#     h = zeros(6)
#     cone = CO.Cone([CO.EpiNormInf(6)], [1:6])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#     @test r.x ≈ zeros(6) atol=1e-4 rtol=1e-4
# end
#
# function epinorminf4(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[0, 1, -1]
#     A = Float64[1 0 0; 0 1 0]
#     b = Float64[1, -0.4]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#     cone = CO.Cone([CO.EpiNormInf(3, true)], [1:3])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ -1 atol=1e-4 rtol=1e-4
#     @test r.x ≈ [1, -0.4, 0.6] atol=1e-4 rtol=1e-4
#     @test r.y ≈ [1, 0] atol=1e-4 rtol=1e-4
# end
#
# function epinorminf5(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     Random.seed!(1)
#     c = Float64[1, 0, 0, 0, 0, 0]
#     A = rand(-9.0:9.0, 3, 6)
#     b = A*ones(6)
#     G = rand(6, 6)
#     h = G*ones(6)
#     cone = CO.Cone([CO.EpiNormInf(6, true)], [1:6])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 15
#     @test r.primal_obj ≈ 1 atol=1e-4 rtol=1e-4
# end
#
# function epinorminf6(; verbose::Bool = true)
#     Random.seed!(1)
#     l = 3
#     L = 2l + 1
#     c = collect(-Float64(l):Float64(l))
#     A = spzeros(2, L)
#     A[1,1] = A[1,L] = A[2,1] = 1.0; A[2,L] = -1.0
#     b = [0.0, 0.0]
#     G = [spzeros(1, L); sparse(1.0I, L, L); spzeros(1, L); sparse(2.0I, L, L)]
#     h = zeros(2L+2); h[1] = 1.0; h[L+2] = 1.0
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     cone = CO.Cone([CO.EpiNormInf(L+1, true), CO.EpiNormInf(L+1, false)], [1:L+1, L+2:2L+2])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 25
#     @test r.primal_obj ≈ -l + 1 atol=1e-4 rtol=1e-4
#     @test r.x[2] ≈ 0.5 atol=1e-4 rtol=1e-4
#     @test r.x[end-1] ≈ -0.5 atol=1e-4 rtol=1e-4
#     @test sum(abs, r.x) ≈ 1.0 atol=1e-4 rtol=1e-4
# end
#
# function epinormeucl1(; verbose::Bool = true)
#     c = Float64[0, -1, -1]
#     A = Float64[1 0 0; 0 1 0]
#     b = Float64[1, 1/sqrt(2)]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiNormEucl(3, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ -sqrt(2) atol=1e-4 rtol=1e-4
#         @test r.x ≈ [1, 1/sqrt(2), 1/sqrt(2)] atol=1e-4 rtol=1e-4
#         @test r.y ≈ [sqrt(2), 0] atol=1e-4 rtol=1e-4
#     end
# end
#
# function epinormeucl2(; verbose::Bool = true)
#     c = Float64[0, -1, -1]
#     A = Float64[1 0 0]
#     b = Float64[0]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiNormEucl(3, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#         @test r.x ≈ zeros(3) atol=1e-4 rtol=1e-4
#     end
# end
#
# function epipersquare1(; verbose::Bool = true)
#     c = Float64[0, 0, -1, -1]
#     A = Float64[1 0 0 0; 0 1 0 0]
#     b = Float64[1/2, 1]
#     G = SparseMatrixCSC(-1.0I, 4, 4)
#     h = zeros(4)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiPerSquare(4, isdual)], [1:4])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ -sqrt(2) atol=1e-4 rtol=1e-4
#         @test r.x[3:4] ≈ [1, 1]/sqrt(2) atol=1e-4 rtol=1e-4
#     end
# end
#
# function epipersquare2(; verbose::Bool = true)
#     c = Float64[0, 0, -1]
#     A = Float64[1 0 0; 0 1 0]
#     b = Float64[1/2, 1]/sqrt(2)
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiPerSquare(3, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 15
#         @test r.primal_obj ≈ -1/sqrt(2) atol=1e-4 rtol=1e-4
#         @test r.x[2] ≈ 1/sqrt(2) atol=1e-4 rtol=1e-4
#     end
# end
#
# function epipersquare3(; verbose::Bool = true)
#     c = Float64[0, 1, -1, -1]
#     A = Float64[1 0 0 0]
#     b = Float64[0]
#     G = SparseMatrixCSC(-1.0I, 4, 4)
#     h = zeros(4)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiPerSquare(4, isdual)], [1:4])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#         @test r.x ≈ zeros(4) atol=1e-4 rtol=1e-4
#     end
# end
#
# function semidefinite1(; verbose::Bool = true)
#     c = Float64[0, -1, 0]
#     A = Float64[1 0 0; 0 0 1]
#     b = Float64[1/2, 1]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.PosSemidef(3, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ -1 atol=1e-4 rtol=1e-4
#         @test r.x[2] ≈ 1 atol=1e-4 rtol=1e-4
#     end
# end
#
# function semidefinite2(; verbose::Bool = true)
#     c = Float64[0, -1, 0]
#     A = Float64[1 0 1]
#     b = Float64[0]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.PosSemidef(3, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#         @test r.x ≈ zeros(3) atol=1e-4 rtol=1e-4
#     end
# end
#
# function semidefinite3(; verbose::Bool = true)
#     c = Float64[1, 0, 1, 0, 0, 1]
#     A = Float64[1 2 3 4 5 6; 1 1 1 1 1 1]
#     b = Float64[10, 3]
#     G = SparseMatrixCSC(-1.0I, 6, 6)
#     h = zeros(6)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.PosSemidef(6, isdual)], [1:6])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ 1.249632 atol=1e-4 rtol=1e-4
#         @test r.x ≈ [0.491545, 0.647333, 0.426249, 0.571161, 0.531874, 0.331838] atol=1e-4 rtol=1e-4
#     end
# end
#
# function hypoperlog1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[1, 1, 1]
#     A = Float64[0 1 0; 1 0 0]
#     b = Float64[2, 1]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#     cone = CO.Cone([CO.HypoPerLog()], [1:3])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ 2*exp(1/2)+3 atol=1e-4 rtol=1e-4
#     @test r.x ≈ [1, 2, 2*exp(1/2)] atol=1e-4 rtol=1e-4
#     @test r.y ≈ -[1+exp(1/2)/2, 1+exp(1/2)] atol=1e-4 rtol=1e-4
#     @test r.z ≈ c+A'*r.y atol=1e-4 rtol=1e-4
# end
#
# function hypoperlog2(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[-1, 0, 0]
#     A = Float64[0 1 0]
#     b = Float64[0]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#     cone = CO.Cone([CO.HypoPerLog()], [1:3])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 25
#     @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
# end
#
# function hypoperlog3(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[1, 1, 1]
#     A = Matrix{Float64}(undef, 0, 3)
#     b = Vector{Float64}(undef, 0)
#     G = sparse([1, 2, 3, 4], [1, 2, 3, 1], -ones(4))
#     h = zeros(4)
#     cone = CO.Cone([CO.HypoPerLog(), CO.Nonnegative(1)], [1:3, 4:4])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#     @test r.x ≈ [0, 0, 0] atol=1e-4 rtol=1e-4
#     @test isempty(r.y)
# end
#
# function hypoperlog4(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[0, 0, 1]
#     A = Float64[0 1 0; 1 0 0]
#     b = Float64[1, -1]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#     cone = CO.Cone([CO.HypoPerLog(true)], [1:3])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ exp(-2) atol=1e-4 rtol=1e-4
#     @test r.x ≈ [-1, 1, exp(-2)] atol=1e-4 rtol=1e-4
# end
#
# function epiperpower1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[1, 0, -1, 0, 0, -1]
#     A = Float64[1 1 0 1/2 0 0; 0 0 0 0 1 0]
#     b = Float64[2, 1]
#     G = SparseMatrixCSC(-1.0I, 6, 6)
#     h = zeros(6)
#     cone = CO.Cone([CO.EpiPerPower(5.0, false), CO.EpiPerPower(2.5, false)], [1:3, 4:6])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.primal_obj ≈ -1.80734 atol=1e-4 rtol=1e-4
#     @test r.x[[1,2,4]] ≈ [0.0639314, 0.783361, 2.30542] atol=1e-4 rtol=1e-4
# end
#
# function epiperpower2(; verbose::Bool = true)
#     c = Float64[0, 0, -1]
#     A = Float64[1 0 0; 0 1 0]
#     b = Float64[1/2, 1]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiPerPower(2.0, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ (isdual ? -sqrt(2) : -1/sqrt(2)) atol=1e-4 rtol=1e-4
#         @test r.x[1:2] ≈ [1/2, 1] atol=1e-4 rtol=1e-4
#     end
# end
#
# function epiperpower3(; verbose::Bool = true)
#     c = Float64[0, 0, 1]
#     A = Float64[1 0 0; 0 1 0]
#     b = Float64[0, 1]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = HYP.Model(verbose=verbose, tolfeas=1e-9)
#         cone = CO.Cone([CO.EpiPerPower(2.0, isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 50
#         @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#         @test r.x[1:2] ≈ [0, 1] atol=1e-4 rtol=1e-4
#     end
# end
#
# function hypogeomean1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     c = Float64[1, 0, 0, -1, -1, 0]
#     A = Float64[1 1 1/2 0 0 0; 0 0 0 0 0 1]
#     b = Float64[2, 1]
#     G = SparseMatrixCSC(-1.0I, 6, 6)[[4, 1, 2, 5, 3, 6], :]
#     h = zeros(6)
#     cone = CO.Cone([CO.HypoGeomean([0.2, 0.8], false), CO.HypoGeomean([0.4, 0.6], false)], [1:3, 4:6])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 25
#     @test r.primal_obj ≈ -1.80734 atol=1e-4 rtol=1e-4
#     @test r.x[1:3] ≈ [0.0639314, 0.783361, 2.30542] atol=1e-4 rtol=1e-4
# end
#
# function hypogeomean2(; verbose::Bool = true)
#     c = Float64[-1, 0, 0]
#     A = Float64[0 0 1; 0 1 0]
#     b = Float64[1/2, 1]
#     G = SparseMatrixCSC(-1.0I, 3, 3)
#     h = zeros(3)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.HypoGeomean([0.5, 0.5], isdual)], [1:3])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         @test r.primal_obj ≈ (isdual ? 0 : -1/sqrt(2)) atol=1e-4 rtol=1e-4
#         @test r.x[2:3] ≈ [1, 0.5] atol=1e-4 rtol=1e-4
#     end
# end
#
# function hypogeomean3(; verbose::Bool = true)
#     l = 4
#     c = vcat(0.0, ones(l))
#     A = [1.0 zeros(1, l)]
#     G = SparseMatrixCSC(-1.0I, l+1, l+1)
#     h = zeros(l+1)
#
#     for isdual in [true, false]
#         b = (isdual ? [-1.0] : [1.0])
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.HypoGeomean(fill(1/l, l), isdual)], [1:l+1])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 25
#         @test r.primal_obj ≈ (isdual ? 1 : l) atol=1e-4 rtol=1e-4
#         @test r.x[2:end] ≈ (isdual ? fill(1/l, l) : ones(l)) atol=1e-4 rtol=1e-4
#     end
# end
#
# function hypogeomean4(; verbose::Bool = true)
#     l = 4
#     c = ones(l)
#     A = zeros(0, l)
#     b = zeros(0)
#     G = [zeros(1, l); Matrix(-1.0I, l, l)]
#     h = zeros(l+1)
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.HypoGeomean(fill(1/l, l), isdual)], [1:l+1])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 15
#         @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
#         @test r.x ≈ zeros(l) atol=1e-4 rtol=1e-4
#     end
# end
#
# function epinormspectral1(; verbose::Bool = true)
#     Random.seed!(1)
#     (Xn, Xm) = (3, 4)
#     Xnm = Xn*Xm
#     c = vcat(1.0, zeros(Xnm))
#     p = 0
#     A = [spzeros(Xnm, 1) sparse(1.0I, Xnm, Xnm)]
#     b = rand(Xnm)
#     G = sparse(-1.0I, Xnm+1, Xnm+1)
#     h = vcat(0.0, rand(Xnm))
#
#     for isdual in [true, false]
#         model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#         cone = CO.Cone([CO.EpiNormSpectral(Xn, Xm, isdual)], [1:Xnm+1])
#         solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#         @test r.status == :Optimal
#         @test r.num_iters <= 20
#         if isdual
#             @test sum(svdvals!(reshape(r.s[2:end], Xn, Xm))) ≈ r.s[1] atol=1e-4 rtol=1e-4
#             @test svdvals!(reshape(r.z[2:end], Xn, Xm))[1] ≈ r.z[1] atol=1e-4 rtol=1e-4
#         else
#             @test svdvals!(reshape(r.s[2:end], Xn, Xm))[1] ≈ r.s[1] atol=1e-4 rtol=1e-4
#             @test sum(svdvals!(reshape(r.z[2:end], Xn, Xm))) ≈ r.z[1] atol=1e-4 rtol=1e-4
#         end
#     end
# end
#
# function hypoperlogdet1(; verbose::Bool = true)
#     Random.seed!(1)
#     side = 4
#     dim = round(Int, 2 + side*(side + 1)/2)
#     c = [-1.0, 0.0]
#     A = [0.0 1.0]
#     b = [1.0]
#     G = SparseMatrixCSC(-1.0I, dim, 2)
#     mathalf = rand(side, side)
#     mat = mathalf*mathalf'
#     h = zeros(dim)
#     CO.smat_to_svec!(view(h, 3:dim), mat)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     cone = CO.Cone([CO.HypoPerLogdet(dim)], [1:dim])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 30
#     @test r.x[1] ≈ -r.primal_obj atol=1e-4 rtol=1e-4
#     @test r.x[2] ≈ 1 atol=1e-4 rtol=1e-4
#     @test r.s[2]*logdet(CO.svec_to_smat!(zeros(side, side), r.s[3:end])/r.s[2]) ≈ r.s[1] atol=1e-4 rtol=1e-4
#     @test r.z[1]*(logdet(CO.svec_to_smat!(zeros(side, side), -r.z[3:end])/r.z[1]) + side) ≈ r.z[2] atol=1e-4 rtol=1e-4
# end
#
# function hypoperlogdet2(; verbose::Bool = true)
#     Random.seed!(1)
#     side = 3
#     dim = round(Int, 2 + side*(side + 1)/2)
#     c = [0.0, 1.0]
#     A = [1.0 0.0]
#     b = [-1.0]
#     G = SparseMatrixCSC(-1.0I, dim, 2)
#     mathalf = rand(side, side)
#     mat = mathalf*mathalf'
#     h = zeros(dim)
#     CO.smat_to_svec!(view(h, 3:dim), mat)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     cone = CO.Cone([CO.HypoPerLogdet(dim, true)], [1:dim])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 25
#     @test r.x[2] ≈ r.primal_obj atol=1e-4 rtol=1e-4
#     @test r.x[1] ≈ -1 atol=1e-4 rtol=1e-4
#     @test r.s[1]*(logdet(CO.svec_to_smat!(zeros(side, side), -r.s[3:end])/r.s[1]) + side) ≈ r.s[2] atol=1e-4 rtol=1e-4
#     @test r.z[2]*logdet(CO.svec_to_smat!(zeros(side, side), r.z[3:end])/r.z[2]) ≈ r.z[1] atol=1e-4 rtol=1e-4
# end
#
# function hypoperlogdet3(; verbose::Bool = true)
#     Random.seed!(1)
#     side = 3
#     dim = round(Int, 2 + side*(side + 1)/2)
#     c = [-1.0, 0.0]
#     A = [0.0 1.0]
#     b = [0.0]
#     G = SparseMatrixCSC(-1.0I, dim, 2)
#     mathalf = rand(side, side)
#     mat = mathalf*mathalf'
#     h = zeros(dim)
#     CO.smat_to_svec!(view(h, 3:dim), mat)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     cone = CO.Cone([CO.HypoPerLogdet(dim)], [1:dim])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 30
#     @test r.x[1] ≈ -r.primal_obj atol=1e-4 rtol=1e-4
#     @test r.x ≈ [0, 0] atol=1e-4 rtol=1e-4
# end
#
# function epipersumexp1(; verbose::Bool = true)
#     l = 5
#     c = vcat(0.0, -ones(l))
#     A = [1.0 zeros(1, l)]
#     b = [1.0]
#     G = [-1.0 spzeros(1, l); spzeros(1, l+1); spzeros(l, 1) sparse(-1.0I, l, l)]
#     h = zeros(l+2)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     cone = CO.Cone([CO.EpiPerSumExp(l+2)], [1:l+2])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 30
#     @test r.x[1] ≈ 1 atol=1e-4 rtol=1e-4
#     @test r.s[2] ≈ 0 atol=1e-4 rtol=1e-4
#     @test r.s[1] ≈ 1 atol=1e-4 rtol=1e-4
# end
#
# function epipersumexp2(; verbose::Bool = true)
#     l = 5
#     c = vcat(0.0, -ones(l))
#     A = [1.0 zeros(1, l)]
#     b = [1.0]
#     G = [-1.0 spzeros(1, l); spzeros(1, l+1); spzeros(l, 1) sparse(-1.0I, l, l)]
#     h = zeros(l+2); h[2] = 1.0
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     cone = CO.Cone([CO.EpiPerSumExp(l+2)], [1:l+2])
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 20
#     @test r.x[1] ≈ 1 atol=1e-4 rtol=1e-4
#     @test r.s[2] ≈ 1 atol=1e-4 rtol=1e-4
#     @test r.s[2]*sum(exp, r.s[3:end]/r.s[2]) ≈ r.s[1] atol=1e-4 rtol=1e-4
# end
#
#
# function envelope1(; verbose::Bool = true)
#     # dense methods
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_envelope(2, 5, 1, 5, use_data=true, usedense=true)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.primal_obj ≈ 25.502777 atol=1e-4 rtol=1e-4
#     @test r.num_iters <= 35
#
#     # sparse methods
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_envelope(2, 5, 1, 5, use_data=true, usedense=false)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.primal_obj ≈ 25.502777 atol=1e-4 rtol=1e-4
#     @test r.num_iters <= 35
# end
#
# function envelope2(; verbose::Bool = true)
#     # dense methods
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_envelope(2, 4, 2, 7, usedense=true)
#     rd = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
#     @test rd.status == :Optimal
#     @test rd.num_iters <= 60
#
#     # sparse methods
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_envelope(2, 4, 2, 7, usedense=false)
#     rs = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
#     @test rs.status == :Optimal
#     @test rs.num_iters <= 60
#
#     @test rs.primal_obj ≈ rd.primal_obj atol=1e-4 rtol=1e-4
# end
#
# function envelope3(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_envelope(2, 3, 3, 5, usedense=false)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 60
# end
#
# function envelope4(; verbose::Bool = true)
#     model = HYP.Model(verbose=verbose, tolrelopt=2e-8, tolabsopt=2e-8, tolfeas=1e-8)
#     (c, A, b, G, h, cone) = build_envelope(2, 2, 4, 3, usedense=false)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 55
# end
#
# function linearopt1(; verbose::Bool = true)
#     # dense methods
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_linearopt(25, 50, usedense=true, tosparse=false)
#     rd = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
#     @test rd.status == :Optimal
#     @test rd.num_iters <= 35
#
#     # sparse methods
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_linearopt(25, 50, usedense=true, tosparse=true)
#     rs = solveandcheck(model, IP.HSDESolver(model, verbose=verbose))
#     @test rs.status == :Optimal
#     @test rs.num_iters <= 35
#
#     @test rs.primal_obj ≈ rd.primal_obj atol=1e-4 rtol=1e-4
# end
#
# function linearopt2(; verbose::Bool = true)
#     model = HYP.Model(verbose=verbose, tolrelopt=2e-8, tolabsopt=2e-8, tolfeas=1e-8)
#     (c, A, b, G, h, cone) = build_linearopt(500, 1000, use_data=true, usedense=true)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 70
#     @test r.primal_obj ≈ 2055.807 atol=1e-4 rtol=1e-4
# end
#
# # for namedpoly tests, most optimal values are taken from https://people.sc.fsu.edu/~jburkardt/py_src/polynomials/polynomials.html
#
# function namedpoly1(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:butcher, 2)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 45
#     @test r.primal_obj ≈ -1.4393333333 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly2(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:caprasse, 4)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 45
#     @test r.primal_obj ≈ -3.1800966258 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly3(; verbose::Bool = true)
#     model = HYP.Model(verbose=verbose, tolfeas=1e-9)
#     (c, A, b, G, h, cone) = build_namedpoly(:goldsteinprice, 6)
#     r = solveandcheck(model, c, A, b, G, h, cone, linearsystem, atol=2e-3)
#     @test r.status == :Optimal
#     @test r.num_iters <= 70
#     @test r.primal_obj ≈ 3 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly4(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:heart, 2)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     # @test r.num_iters <= 40
#     @test r.primal_obj ≈ -1.36775 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly5(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:lotkavolterra, 3)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 40
#     @test r.primal_obj ≈ -20.8 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly6(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:magnetism7, 2)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 35
#     @test r.primal_obj ≈ -0.25 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly7(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:motzkin, 7)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 45
#     @test r.primal_obj ≈ 0 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly8(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:reactiondiffusion, 4)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 40
#     @test r.primal_obj ≈ -36.71269068 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly9(; verbose::Bool = true)
#     model = MO.LinearObjConic(c, A, b, G, h, cones, cone_idxs)
#     (c, A, b, G, h, cone) = build_namedpoly(:robinson, 8)
#     solver = IP.HSDESolver(model, verbose=verbose)
    # r = solveandcheck(model, solver)
#     @test r.status == :Optimal
#     @test r.num_iters <= 40
#     @test r.primal_obj ≈ 0.814814 atol=1e-4 rtol=1e-4
# end
#
# function namedpoly10(; verbose::Bool = true)
#     model = HYP.Model(verbose=verbose, tolfeas=2e-10)
#     (c, A, b, G, h, cone) = build_namedpoly(:rosenbrock, 5)
#     r = solveandcheck(model, c, A, b, G, h, cone, linearsystem, atol=1e-3)
#     @test r.status == :Optimal
#     @test r.num_iters <= 70
#     @test r.primal_obj ≈ 0 atol=1e-3 rtol=1e-3
# end
#
# function namedpoly11(; verbose::Bool = true)
#     model = HYP.Model(verbose=verbose, tolfeas=1e-10)
#     (c, A, b, G, h, cone) = build_namedpoly(:schwefel, 4)
#     r = solveandcheck(model, c, A, b, G, h, cone, linearsystem, atol=1e-3)
#     @test r.status == :Optimal
#     @test r.num_iters <= 65
#     @test r.primal_obj ≈ 0 atol=1e-3 rtol=1e-3
# end
