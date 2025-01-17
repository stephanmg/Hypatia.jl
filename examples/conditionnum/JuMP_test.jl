#=
Copyright (c) 2018-2022 Chris Coey, Lea Kapelevich, and contributors

This Julia package Hypatia.jl is released under the MIT license; see LICENSE
file in the root directory or at https://github.com/chriscoey/Hypatia.jl
=#

insts = OrderedDict()
insts["minimal"] = [((3, 2, true),), ((3, 2, false),)]
insts["fast"] = [
    ((3, 4, true),),
    ((3, 4, false),),
    ((10, 15, true),),
    ((10, 15, false),),
    ((20, 10, true),),
    ((100, 40, false),),
]
insts["various"] = [
    ((50, 20, true),),
    ((50, 20, false),),
    ((100, 100, true),),
    ((100, 100, false),),
    ((200, 100, true),),
    ((200, 100, false),),
]
return (ConditionNumJuMP, insts)
