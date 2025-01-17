#=
Copyright (c) 2018-2022 Chris Coey, Lea Kapelevich, and contributors

This Julia package Hypatia.jl is released under the MIT license; see LICENSE
file in the root directory or at https://github.com/chriscoey/Hypatia.jl
=#

insts = OrderedDict()
insts["minimal"] = [((2, 4, 1.0),), ((2, 4, 0.5),)]
insts["fast"] = [
    ((15, 20, 1.0),),
    ((15, 20, 0.25),),
    ((100, 100, 1.0),),
    ((100, 100, 0.15),),
    ((500, 100, 1.0),),
    ((500, 100, 0.15),),
]
insts["various"] = [((250, 1000, 0.1),), ((500, 5000, 0.05),), ((500, 2000, 1.0),)]
return (LinearOptNative, insts)
