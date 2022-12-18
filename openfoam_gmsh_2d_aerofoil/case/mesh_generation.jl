y(x)= 0.594689181*(0.298222773*sqrt(x) - 0.127125232*x - 0.357907906*x^2 + 0.291984971*x^3 - 0.105174606*x^4)
# using Plots
# x=0.0:0.001:1.2
#plot(x,y.(x))
n_points_per_side=200
n_aerofoil_points=2*n_points_per_side
bounding_radius=7.0
far_field_mesh_size=0.3
airfoil_mesh_size=0.03
run(`./set_config_property.sh name unstructured_gmsh_$(airfoil_mesh_size)_$(far_field_mesh_size)`)
touch("aerofoil.geo")
open("aerofoil.geo","w")do io
    for i in 1:n_points_per_side
        x=(i-1)/(n_points_per_side)
        mesh_size=airfoil_mesh_size#0.05#1*x*(1-x)+0.005
        println(io,"Point($i) = {$x, $(y(x)), 0.0,$mesh_size};")
    end
    for i in 1:n_points_per_side
        x=1-(i-1)/(n_points_per_side)
        mesh_size=airfoil_mesh_size#0.05#1*x*(1-x)+0.005
        println(io,"Point($(i+n_points_per_side)) = {$(x), $(-y(x)), 0.0,$mesh_size};")
    end
    for i in 1:2*n_points_per_side
        #println(io,"Line($i) = {$(i%(2*n_points_per_side)+1), $i};")
    end
    println(io,"""Spline(1)={1:$n_aerofoil_points,1};""")
    #println(io,"Curve Loop(10001) = {1};")
    #println(io,"Curve Loop(1) = {1:$n_aerofoil_points};")

    # #println(io,"Physical Curve(\"AEROFOIL\") = {1};")
    println(io,"Point($(n_aerofoil_points+1)) = {0.0, $(bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+2)) = {0.0, $(-bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+3)) = {$(-bounding_radius), 0.0, 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+4)) = {$(bounding_radius), $(bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+5)) = {$(bounding_radius), $(-bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Circle($(n_aerofoil_points+1))= {$(n_aerofoil_points+2), 1, $(n_aerofoil_points+3)};")
    println(io,"Circle($(n_aerofoil_points+2))= {$(n_aerofoil_points+3), 1, $(n_aerofoil_points+1)};")
    println(io,"Line($(n_aerofoil_points+3)) = {$(n_aerofoil_points+1), $(n_aerofoil_points+4)};")
    println(io,"Line($(n_aerofoil_points+4)) = {$(n_aerofoil_points+4), $(n_aerofoil_points+5)};")
    println(io,"Line($(n_aerofoil_points+5)) = {$(n_aerofoil_points+5), $(n_aerofoil_points+2)};")


    println(io,"Curve Loop(2) = {$(join((n_aerofoil_points+1):(n_aerofoil_points+5),","))};")
    println(io,"Curve Loop(3) = {1};")
    println(io,"Plane Surface(1) = {2,3};")
    # #println(io,"Physical Curve(\"WALL\") = {2};")
    #println(io,"Plane Surface(1) = {1,2};")
    println(io,"""
    meshThickness=1.0;
    surfaceVector[] = Extrude {0, 0, meshThickness} {
        Surface{1};
        Layers{1};
        Recombine;
    };
    Physical Volume("internalField") = surfaceVector[1];
    Physical Surface("frontAndBackPlanes") = {surfaceVector[0],1};
    Physical Surface("INLET")={surfaceVector[2],surfaceVector[3]};
    Physical Surface("OUTLET")={surfaceVector[5]};
    Physical Surface("AIRFOIL")={surfaceVector[7]};
    Physical Surface("WALL")={surfaceVector[4],surfaceVector[6]};
    Recombine Surface{1};
    """)

    #println(io,"Physical Curve(\"BOUNDARY\") = {$(join((n_aerofoil_points+1):(n_aerofoil_points+5),","))};")
end
