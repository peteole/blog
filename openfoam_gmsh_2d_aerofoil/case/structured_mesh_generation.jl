y(x)= 0.594689181*(0.298222773*sqrt(x) - 0.127125232*x - 0.357907906*x^2 + 0.291984971*x^3 - 0.105174606*x^4)
# using Plots
# x=0.0:0.001:1.2
#plot(x,y.(x))
n_points_per_side=800
n_aerofoil_points=2*n_points_per_side
bounding_radius=7.0
#far_field_mesh_size=0.5
far_field_mesh_size=0.7
#should be divisible by 3
#n_aerofoil_grid_points=180
n_aerofoil_grid_points=72*2

aerofoil_layer_thickness=0.005
#aerofoil_layer_thickness=0.002
far_field_layer_thickness=far_field_mesh_size

# aerofoil_layer_thickness*ratio^(n_layers-1)=far_field_layer_thickness
# bounding_radius=sum_i(aerofoil_layer_thickness*ratio^i)=aerofoil_layer_thickness*(1-ratio^n_layers)/(1-ratio)
# solve for ratio and n_layers
function compute_ratio_and_n_layers(aerofoil_layer_thickness,far_field_layer_thickness,bounding_radius)
    n_layers=2
    while true
        ratio=(far_field_layer_thickness/aerofoil_layer_thickness)^(1/(n_layers-1))
        if aerofoil_layer_thickness*(1-ratio^n_layers)/(1-ratio)>bounding_radius
            return ratio,n_layers
        end
        n_layers+=1
    end
    return ratio,n_layers
end
ratio,n_layers=compute_ratio_and_n_layers(aerofoil_layer_thickness,far_field_layer_thickness,bounding_radius)
println("ratio=$ratio, n_layers=$n_layers")
run(`./set_config_property.sh name structured_gmsh_$(aerofoil_layer_thickness)_$(far_field_layer_thickness)_$(n_aerofoil_grid_points)`)
touch("aerofoil_str.geo")
open("aerofoil_str.geo","w")do io
    for i in 1:n_points_per_side
        x=(i-1)/(n_points_per_side)
        mesh_size=0.0035#1*x*(1-x)+0.005
        println(io,"Point($i) = {$x, $(y(x)), 0.0,$mesh_size};")
    end
    for i in 1:n_points_per_side
        x=1-(i-1)/(n_points_per_side)
        mesh_size=0.0035#1*x*(1-x)+0.005
        println(io,"Point($(i+n_points_per_side)) = {$(x), $(-y(x)), 0.0,$mesh_size};")
    end
    for i in 1:2*n_points_per_side
        #println(io,"Line($i) = {$(i%(2*n_points_per_side)+1), $i};")
    end
    println(io,"""Spline(1)={1:$(n_points_per_side+1)};""")
    println(io,"""Spline(2)={$(n_points_per_side+1):$(2*n_points_per_side),1};""")
    #println(io,"Curve Loop(10001) = {1};")
    #println(io,"Curve Loop(1) = {1:$n_aerofoil_points};")

    # #println(io,"Physical Curve(\"AEROFOIL\") = {1};")
    println(io,"Point($(n_aerofoil_points+1)) = {0.0, $(bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+2)) = {0.0, $(-bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+3)) = {$(-bounding_radius), 0.0, 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+4)) = {$(bounding_radius), $(bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+5)) = {$(bounding_radius), $(-bounding_radius), 0.0, $far_field_mesh_size};")
    println(io,"Point($(n_aerofoil_points+6)) = {$(bounding_radius), 0.0 , 0.0, $far_field_mesh_size};")
    println(io,"Circle($(n_aerofoil_points+1))= {$(n_aerofoil_points+2), 1, $(n_aerofoil_points+3)};")
    println(io,"Circle($(n_aerofoil_points+2))= {$(n_aerofoil_points+3), 1, $(n_aerofoil_points+1)};")
    println(io,"Line($(n_aerofoil_points+3)) = {$(n_aerofoil_points+1), $(n_aerofoil_points+4)};")
    println(io,"Line($(n_aerofoil_points+4)) = {$(n_aerofoil_points+4), $(n_aerofoil_points+6)};")
    println(io,"Line($(n_aerofoil_points+5)) = {$(n_aerofoil_points+6), $(n_aerofoil_points+5)};")
    println(io,"Line($(n_aerofoil_points+6)) = {$(n_aerofoil_points+5), $(n_aerofoil_points+2)};")
    println(io,"Line($(n_aerofoil_points+7)) = {$(n_aerofoil_points+3), 1};")
    println(io,"Line($(n_aerofoil_points+8)) = {$(n_points_per_side+1), $(n_aerofoil_points+6)};")


    println(io,"""
        Curve Loop(2) = {$(join((n_aerofoil_points+2):(n_aerofoil_points+4),",")),-$(n_aerofoil_points+8),-1,-$(n_aerofoil_points+7)};
        Plane Surface(1) = {2};
        Transfinite Curve{1} = $(n_aerofoil_grid_points-2);
        Transfinite Curve{2} = $(n_aerofoil_grid_points-2);
        Transfinite Curve{$(n_aerofoil_points+7)} = $(n_layers) Using Progression 1/$ratio;
        Transfinite Curve{$(n_aerofoil_points+8)} = $(n_layers) Using Progression $ratio;
        Transfinite Curve{$(n_aerofoil_points+2)} = $(n_aerofoil_grid_points/3);
        Transfinite Curve{$(n_aerofoil_points+3)} = $(n_aerofoil_grid_points/3);
        Transfinite Curve{$(n_aerofoil_points+4)} = $(n_aerofoil_grid_points/3);
        Transfinite Surface{1} = {1,$(n_aerofoil_points+3),$(n_aerofoil_points+6),$(n_points_per_side+1)};
        Recombine Surface{1};

        Transfinite Curve{$(n_aerofoil_points+1)} = $(n_aerofoil_grid_points/3);
        Transfinite Curve{$(n_aerofoil_points+5)} = $(n_aerofoil_grid_points/3);
        Transfinite Curve{$(n_aerofoil_points+6)} = $(n_aerofoil_grid_points/3);
        


        //same for the lower side
        Curve Loop(3) = {-$(n_aerofoil_points+8),2,-$(n_aerofoil_points+7),-$(n_aerofoil_points+1),-$(n_aerofoil_points+6),-$(n_aerofoil_points+5)};
        Plane Surface(2) = {3};
        Transfinite Surface{2}={1,$(n_aerofoil_points+3),$(n_aerofoil_points+6),$(n_points_per_side+1)};
        Recombine Surface{2};

        meshThickness=1.0;
        surfaceVector[] = Extrude {0, 0, meshThickness} {
            Surface{1,2};
            Layers{1};
            Recombine;
        };
        Printf("Surfaces: $(repeat("%g,",14))", $(join(["surfaceVector[$i]" for i in 0:13],",")));


        Physical Surface("WALL")={surfaceVector[3],surfaceVector[14]};
        Physical Surface("frontAndBackPlanes") = {surfaceVector[0],surfaceVector[8],1,2};
        Physical Surface("OUTLET")={surfaceVector[4],surfaceVector[15]};
        Physical Volume("internalField") = {surfaceVector[1],surfaceVector[9]};
        Physical Surface("INLET")={surfaceVector[2],surfaceVector[13]};
        Physical Surface("AIRFOIL")={surfaceVector[6],surfaceVector[11]};
        Mesh.Smoothing = 20;
        """)
end