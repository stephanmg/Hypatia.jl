#=
Copyright (c) 2018-2022 Chris Coey, Lea Kapelevich, and contributors

This Julia package Hypatia.jl is released under the MIT license; see LICENSE
file in the root directory or at https://github.com/chriscoey/Hypatia.jl
=#

relaxed_tols = (default_tol_relax = 1000,)
insts = OrderedDict()
insts["minimal"] = [
    ((:naics5811, 3, true, false, true, true, false),),
    ((:naics5811, 3, true, false, true, false, false),),
    ((2, 5, :func2, 2, 4, true, false, true, false, false),),
    ((1, 5, :func4, 2, 4, true, false, false, false, true),),
    ((1, 5, :func6, 2, 4, false, false, true, true, false),),
    ((1, 5, :func7, 2, 4, false, true, true, true, false), :SOCExpPSD),
    ((1, 5, :func1, 2, 4, false, true, false, false, true), :SOCExpPSD),
]
insts["fast"] = [
    ((:naics5811, 4, true, false, true, true, false),),
    ((:naics5811, 4, true, true, true, true, false),),
    ((:naics5811, 3, false, false, true, true, false),),
    ((:naics5811, 3, false, true, true, true, false), :SOCExpPSD),
    ((:naics5811, 3, false, true, true, true, false),),
    ((:naics5811, 3, false, false, true, true, false),),
    ((:naics5811, 3, false, true, true, false, false), :SOCExpPSD),
    ((1, 100, :func1, 5, 10, true, false, true, true, false),),
    ((1, 100, :func1, 5, 20, false, false, false, true, false),),
    ((1, 100, :func1, 5, 50, true, false, false, true, false),),
    ((1, 100, :func1, 5, 80, true, false, false, true, false),),
    ((1, 100, :func1, 5, 100, true, false, false, true, false),),
    ((1, 200, :func4, 5, 100, true, false, false, true, false),),
    ((2, 50, :func1, 5, 5, true, false, true, true, false),),
    ((2, 50, :func1, 5, 3, true, false, true, false, false),),
    ((2, 50, :func1, 5, 3, true, false, false, true, false),),
    ((2, 200, :func1, 0, 3, true, false, false, false, true),),
    ((2, 50, :func2, 5, 3, true, true, true, true, false),),
    ((2, 50, :func3, 10, 3, false, true, false, true, false),),
    ((2, 50, :func3, 10, 3, true, true, false, true, false),),
    ((2, 50, :func3, 5, 3, false, true, true, true, false), :SOCExpPSD),
    ((2, 50, :func4, 5, 3, false, true, true, true, false),),
    ((2, 50, :func4, 5, 3, false, true, true, true, false), :SOCExpPSD),
    ((2, 50, :func5, 5, 4, true, false, true, true, false),),
    ((2, 50, :func6, 5, 4, true, true, true, true, false),),
    ((2, 50, :func7, 5, 4, false, false, true, true, false),),
    ((2, 50, :func8, 5, 4, false, true, true, true, false),),
    ((4, 150, :func7, 0, 4, true, false, true, true, true),),
    ((4, 150, :func7, 0, 4, true, true, true, true, true),),
    ((4, 150, :func7, 0, 4, false, false, true, true, true),),
    ((3, 150, :func8, 0, 6, true, false, true, true, true),),
]
insts["various"] = [
    ((8, 100, :func4, 5, 3, true, true, true, true, false),),
    ((8, 100, :func4, 5, 3, true, false, true, true, false),),
    ((8, 100, :func4, 5, 3, false, true, true, true, false),),
    ((8, 100, :func4, 5, 3, false, false, true, true, false),),
    ((5, 500, :func4, 5, 6, true, true, true, true, false), nothing, relaxed_tols),
    ((5, 500, :func4, 5, 6, true, false, true, true, false),),
    ((:naics5811, 3, true, true, true, true, false),),
    ((:naics5811, 3, true, false, true, true, false),),
    ((:naics5811, 3, false, true, true, true, false),),
    ((:naics5811, 3, false, true, true, true, false), :SOCExpPSD),
    ((:naics5811, 3, false, false, true, true, false),),
]
return (ShapeConRegrJuMP, insts)
