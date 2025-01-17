#=
Copyright (c) 2018-2022 Chris Coey, Lea Kapelevich, and contributors

This Julia package Hypatia.jl is released under the MIT license; see LICENSE
file in the root directory or at https://github.com/chriscoey/Hypatia.jl
=#

insts = OrderedDict()
insts["minimal"] = [
    ((2, false, true, true, true),),
    ((2, false, false, true, true),),
    ((2, true, true, true, true),),
    ((2, true, false, true, true),),
    ((2, false, true, true, false),),
    ((2, false, false, true, false),),
    ((2, true, true, true, false),),
    ((2, true, false, true, false),),
    ((2, false, false, false, false),),
    ((2, true, false, false, false),),
]
insts["fast"] = [
    ((5, false, true, true, true),),
    ((5, false, false, true, false),),
    ((5, true, true, true, false),),
    ((5, true, false, true, true),),
    ((5, false, true, false, false),),
    ((5, false, false, false, false),),
    ((5, true, true, false, false),),
    ((5, true, false, false, false),),
    ((20, false, true, true, false),),
    ((20, false, false, true, true),),
    ((20, true, true, true, true),),
    ((20, true, false, true, false),),
    ((20, false, true, false, false),),
    ((20, false, false, false, false),),
    ((20, true, true, false, false),),
    ((20, true, false, false, false),),
    ((100, false, true, false, false),),
    ((100, false, false, false, false),),
]
insts["various"] = [
    ((50, false, true, true, true),),
    ((50, false, false, true, true),),
    ((50, true, true, true, false),),
    ((50, true, false, true, false),),
    ((50, false, true, false, false),),
    ((50, false, false, false, false),),
    ((50, true, true, false, false),),
    ((50, true, false, false, false),),
    ((100, false, true, true, true),),
    ((100, false, false, true, false),),
    ((100, true, true, true, false),),
    ((100, true, false, true, true),),
    ((100, false, true, false, false),),
    ((100, false, false, false, false),),
    ((100, true, true, false, false),),
    ((100, true, false, false, false),),
    ((200, false, true, false, false),),
    ((200, false, false, false, false),),
    ((200, false, true, true, false),),
    ((200, false, false, true, false),),
    ((200, true, true, true, true),),
    ((200, true, false, true, true),),
    ((400, false, true, false, false),),
    ((400, false, false, false, false),),
    ((400, false, true, true, false),),
    ((400, false, false, true, true),),
    ((400, true, true, true, true),),
    ((400, true, false, true, false),),
]
return (NearestPSDJuMP, insts)
