#=
Copyright 2020, Chris Coey, Lea Kapelevich and contributors

run benchmarks from the examples folder
to use the bench instance set and run on cmd line:
~/julia/julia test/runexamplestests.jl &> ~/bench/bench.txt
=#

import DataFrames
import CSV
using Printf
import TimerOutputs
import LinearAlgebra
using Hypatia
using MosekTools

examples_dir = @__DIR__

# path to write results DataFrame to CSV, if any
results_path = joinpath(homedir(), "bench", "bench.csv")
# results_path = nothing

free_memory_limit = 16 * 2^30 # keep at least X GB of RAM available
time_limit = 1800 * 1.1

num_threads = Threads.nthreads()
blas_num_threads = LinearAlgebra.BLAS.get_num_threads()
@show num_threads
@show blas_num_threads
println()

# options to solvers
tol = 1e-7
hyp_solver = ("Hypatia", Hypatia.Optimizer, (
    verbose = true,
    iter_limit = 250,
    time_limit = time_limit,
    tol_abs_opt = tol,
    tol_rel_opt = tol,
    tol_feas = tol,
    ))
mosek_solver = ("Mosek", Mosek.Optimizer, (
    QUIET = false,
    MSK_IPAR_NUM_THREADS = blas_num_threads,
    MSK_DPAR_OPTIMIZER_MAX_TIME = time_limit,
    MSK_DPAR_INTPNT_CO_TOL_PFEAS = tol,
    MSK_DPAR_INTPNT_CO_TOL_DFEAS = tol,
    MSK_DPAR_INTPNT_CO_TOL_REL_GAP = tol,
    ))

# instance sets and solvers to run
instance_sets = [
    ("nat", [hyp_solver,]),
    ("ext", [
        hyp_solver,
        mosek_solver,
        ]),
    ]

# models to run
JuMP_example_names = [
    "densityest",
    # "expdesign",
    # "matrixcompletion",
    # "matrixquadratic",
    # "matrixregression",
    # "nearestpsd",
    # "polymin",
    # "portfolio",
    # "shapeconregr",
    ]

using Distributed

# reduce printing for worker
Base.eval(Distributed, :(function redirect_worker_output(ident, stream)
    @async while !eof(stream)
        println(readline(stream))
    end
end))

function get_worker()
    if nprocs() < 2
        addprocs(1, enable_threaded_blas = true, exeflags = `--threads $num_threads`)
        sleep(1)
    end
    return workers()[end]
end

function spawn_instance(worker, ex_type, inst, extender, solver)
    time_inst = time()

    t = @spawnat worker test(ex_type{Float64}, inst, extender, solver[3], solver[2])
    sleep(1)

    status = :ScriptError
    try
        is_killed = false
        while !isready(t)
            sleep(1)
            if Sys.free_memory() < free_memory_limit
                status = :KilledMemory
                is_killed = true
                break
            elseif time() - time_inst > time_limit
                status = :KilledTime
                is_killed = true
                break
            end
        end
        time_inst = time() - time_inst
        if is_killed
            status = :Killed
        else
            (_, build_time, r) = fetch(t)
            return (false, (build_time, r.status, r.solve_time, r.num_iters, r.primal_obj, r.dual_obj, r.obj_diff, r.compl, r.x_viol, r.y_viol, r.z_viol, r.n, r.p, r.q, r.cones))
        end
    catch e
        println(e)
    end

    return (true, (NaN, status, NaN, 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 0, 0, 0, String[]))
end

function run_benchmarks()
    @info("starting benchmark runs")

    worker = get_worker()
    @everywhere @eval using MosekTools
    @everywhere include(joinpath($examples_dir, "common.jl"))
    @everywhere include(joinpath($examples_dir, "common_JuMP.jl"))

    perf = DataFrames.DataFrame(
        example = Type{<:ExampleInstance}[],
        inst_set = String[],
        count = Int[],
        inst_data = Tuple[],
        solver = String[],
        extender = Any[],
        total_time = Float64[],
        build_time = Float64[],
        status = Symbol[],
        solve_time = Float64[],
        iters = Int[],
        prim_obj = Float64[],
        dual_obj = Float64[],
        obj_diff = Float64[],
        compl = Float64[],
        x_viol = Float64[],
        y_viol = Float64[],
        z_viol = Float64[],
        n = Int[],
        p = Int[],
        q = Int[],
        cones = Vector{String}[]
        )

    isnothing(results_path) || CSV.write(results_path, perf)
    time_all = time()

    for ex_name in JuMP_example_names
        @everywhere include(joinpath($examples_dir, $ex_name, "JuMP.jl"))
        @everywhere (ex_type, ex_insts) = include(joinpath($examples_dir, $ex_name, "benchmark.jl"))
        for (inst_set, solvers) in instance_sets, solver in solvers
            haskey(ex_insts, inst_set) || continue
            (extender, inst_subsets) = ex_insts[inst_set]
            isempty(inst_subsets) && continue
            println("\nstarting instances for $ex_type $inst_set")
            for inst_subset in inst_subsets
                for (inst_num, inst) in enumerate(inst_subset)
                    println("\n$ex_type $inst_set $(solver[1]) $inst_num: $inst ...")

                    sleep(1)
                    time_inst = @elapsed (is_killed, p) = spawn_instance(worker, ex_type, inst, extender, solver)

                    push!(perf, (ex_type, inst_set, inst_num, inst, solver[1], extender, time_inst, p...))
                    isnothing(results_path) || CSV.write(results_path, perf[end:end, :], transform = (col, val) -> something(val, missing), append = true)
                    @printf("... %8.2e seconds\n", time_inst)
                    flush(stdout)
                    flush(stderr)

                    if is_killed
                        worker = get_worker()
                        @spawnat worker begin
                            Base.@eval using MosekTools
                            include(joinpath(examples_dir, "common.jl"))
                            include(joinpath(examples_dir, "common_JuMP.jl"))
                            include(joinpath(examples_dir, ex_name, "JuMP.jl"))
                            include(joinpath(examples_dir, ex_name, "benchmark.jl"))
                        end
                        flush(stdout)
                        flush(stderr)
                        break
                    end
                end
            end
        end
    end

    flush(stdout)
    flush(stderr)
    @printf("\nexamples tests total time: %8.2e seconds\n\n", time() - time_all)
    DataFrames.show(perf, allrows = true, allcols = true)
    println("\n")
    @show sum(perf[:iters])
    flush(stdout)
    flush(stderr)
end

# start the benchmarks
run_benchmarks()
