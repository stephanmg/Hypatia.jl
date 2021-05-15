
insts = Dict()
insts["minimal"] = [
    ((false, 1, 2, true, true),),
    ((false, 1, 2, false, true),),
    ((false, 1, 2, false, false),),
    ((false, 3, 1, false, false),),
    ((true, :abs1d, 1, true, true),),
    ((true, :absball2d, 1, false, true),),
    ((false, :motzkin, 3, false, true),),
    ((false, :motzkin_ball, 3, false, false),),
    ((false, :motzkin_ellipsoid, 3, true, true),),
    ]
insts["fast"] = [
    ((false, 1, 30, true, true),),
    ((false, 1, 30, false, true),),
    ((false, 1, 30, false, false),),
    ((false, 2, 8, true, true),),
    ((false, 3, 6, true, true),),
    ((false, 5, 3, true, true),),
    ((false, 10, 1, true, true),),
    ((false, 10, 1, false, true),),
    ((false, 10, 1, false, false),),
    ((false, 4, 4, true, true),),
    ((false, 4, 4, false, true),),
    ((false, 4, 4, false, false),),
    ((true, :abs1d, 3, true, true),),
    ((true, :absunit1d, 1, true, true),),
    ((true, :absunit1d, 3, true, true),),
    ((true, :negabsunit1d, 2, true, true),),
    ((true, :absball2d, 1, true, true),),
    ((true, :absbox2d, 2, true, true),),
    ((true, :negabsbox2d, 1, true, true),),
    ((true, :denseunit1d, 2, true, true),),
    ((true, :negabsunit1d, 2, false, true),),
    ((true, :absball2d, 1, false, true),),
    ((true, :negabsbox2d, 1, false, true),),
    ((true, :denseunit1d, 2, false, true),),
    ((false, :butcher, 2, true, true),),
    ((false, :caprasse, 4, true, true),),
    ((false, :goldsteinprice, 7, true, true),),
    ((false, :goldsteinprice_ball, 6, true, true),),
    ((false, :goldsteinprice_ellipsoid, 7, true, true),),
    ((false, :heart, 2, true, true),),
    ((false, :lotkavolterra, 3, true, true),),
    ((false, :magnetism7, 2, true, true),),
    ((false, :magnetism7_ball, 2, true, true),),
    ((false, :motzkin, 3, true, true),),
    ((false, :motzkin_ball, 3, true, true),),
    ((false, :motzkin_ellipsoid, 3, true, true),),
    ((false, :reactiondiffusion, 4, true, true),),
    ((false, :robinson, 8, true, true),),
    ((false, :robinson_ball, 8, true, true),),
    ((false, :rosenbrock, 5, true, true),),
    ((false, :rosenbrock_ball, 5, true, true),),
    ((false, :schwefel, 2, true, true),),
    ((false, :schwefel_ball, 2, true, true),),
    ((false, :lotkavolterra, 3, false, true),),
    ((false, :motzkin, 3, false, true),),
    ((false, :motzkin_ball, 3, false, true),),
    ((false, :schwefel, 2, false, true),),
    ((false, :lotkavolterra, 3, false, false),),
    ((false, :motzkin, 3, false, false),),
    ((false, :motzkin_ball, 3, false, false),),
    ]
insts["slow"] = [
    ((false, 4, 5, true, true),),
    ((false, 4, 5, false, true),),
    ((false, 4, 5, false, false),),
    ((false, 2, 30, true, true),),
    ((false, 2, 30, false, true),),
    ((false, 2, 30, false, false),),
    ]
insts["various"] = Tuple[]
return (PolyMinNative, insts)
