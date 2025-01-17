#=
Copyright (c) 2018-2022 Chris Coey, Lea Kapelevich, and contributors

This Julia package Hypatia.jl is released under the MIT license; see LICENSE
file in the root directory or at https://github.com/chriscoey/Hypatia.jl
=#

insts = OrderedDict()
insts["minimal"] = [
    ((false, 2, 3, 4, 0, 0, 0, 0, 0),),
    ((false, 2, 3, 4, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((true, 5, 3, 4, 0, 0, 0, 0, 0),),
    ((true, 5, 3, 4, 0.1, 0.1, 0.1, 0.2, 0.2),),
]
insts["fast"] = [
    ((false, 5, 3, 4, 0, 0, 0, 0, 0),),
    ((false, 5, 3, 4, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((false, 5, 3, 4, 0, 0.1, 0.1, 0, 0),),
    ((false, 3, 4, 5, 0, 0, 0, 0, 0),),
    ((false, 3, 4, 5, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((false, 3, 4, 5, 0, 0.1, 0.1, 0, 0),),
    ((true, 5, 3, 4, 0, 0, 0, 0, 0),),
    ((true, 5, 3, 4, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((true, 5, 3, 4, 0, 0.1, 0.1, 0, 0),),
    ((true, 3, 4, 5, 0, 0, 0, 0, 0),),
    ((true, 3, 4, 5, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((true, 3, 4, 5, 0, 0.1, 0.1, 0, 0),),
    ((false, 15, 10, 20, 0, 0, 0, 0, 0),),
    ((false, 15, 10, 20, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((false, 15, 10, 20, 0, 0.1, 0.1, 0, 0),),
    ((true, 15, 10, 20, 0, 0, 0, 0, 0),),
    ((true, 15, 10, 20, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((true, 15, 10, 20, 0, 0.1, 0.1, 0, 0),),
    ((false, 100, 8, 12, 0, 0, 0, 0, 0),),
    ((false, 100, 8, 12, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((false, 100, 8, 12, 0, 0.1, 0.1, 0, 0),),
    ((true, 100, 8, 12, 0.1, 0.1, 0.1, 0.2, 0.2),),
    ((true, 100, 8, 12, 0, 0.1, 0.1, 0, 0),),
]
return (MatrixRegressionNative, insts)
