CFD modeling of flow behavior over NACA0012 airfoil for wind turbine
applications
================
Ole Petersen
Dec 7, 2022

# Introduction

The starting point is the [NACA0012 tutorial case in
OpenFoam](https://www.openfoam.com/documentation/guides/latest/doc/verification-validation-naca0012-airfoil-2d.html).
Copy this case to your new working directory. In this tutorial, we will
have a look at how to simulate your custom 2d geometry as the tutorial
is intransparent about how the mesh was generated.

# Mesh generation

We will use `gmsh` to generate the mesh. To do so, we will first
generate the geometry using `gmsh`’s geometry format, use the `gmsh` GUI
to debug the geometry and finally generate the mesh.

## Geometry generation

The geometry will look as follows:

![Geometry of our simulation](./images/geometry.png)

The volume in which fluid is to be simulated is the whole body from
which the aerofoil in the middle is cut out. The circle arc on the left
is the inlet while the outlet is the rectangle on the right.  
The whole geometry generation is done in the
[mesh_generation.jl](case/mesh_generation.jl) script, which outputs a
`gmsh` geometry file [aerofoil.geo](case/aerofoil.geo) that `gmsh` can
read. Note that `gmsh` has its own [geometry scripting
language](https://gmsh.info/doc/texinfo/gmsh.html), but I found it
easier to use a proper programming language like `julia` to generate the
geometry.

### Generating the profile

We will simulate a NACA0012 airfoil, which is described by the following
equation:
$$
y(x) = \pm0.594689181\*(0.298222773\*\sqrt{x} - 0.127125232\*x - 0.357907906\*x^2 + 0.291984971\*x^3 - 0.105174606\*x^4)
$$
Now, we will generate a set of points that describe the profile:

``` julia
y(x)= 0.594689181*(0.298222773*sqrt(x) - 0.127125232*x - 0.357907906*x^2 + 0.291984971*x^3 - 0.105174606*x^4)
n_points_per_side=10 # this would be much higher in the real case
n_aerofoil_points=2*n_points_per_side
io=stdout
for i in 1:n_points_per_side
    x=(i-1)/(n_points_per_side)
    mesh_size=0.005
    println(io,"Point($i) = {$x, $(y(x)), 0.0,$mesh_size};")
end
for i in 1:n_points_per_side
    x=1-(i-1)/(n_points_per_side)
    mesh_size=0.005
    println(io,"Point($(i+n_points_per_side)) = {$(x), $(-y(x)), 0.0,$mesh_size};")
end
```

    Point(1) = {0.0, 0.0, 0.0,0.005};
    Point(2) = {0.1, 0.046561895043862704, 0.0,0.005};
    Point(3) = {0.2, 0.056968557150769476, 0.0,0.005};
    Point(4) = {0.3, 0.05948422462775665, 0.0,0.005};
    Point(5) = {0.4, 0.05738266105317275, 0.0,0.005};
    Point(6) = {0.5, 0.05219019673131475, 0.0,0.005};
    Point(7) = {0.6, 0.04479110070446828, 0.0,0.005};
    Point(8) = {0.7, 0.03570927685952479, 0.0,0.005};
    Point(9) = {0.8, 0.025211311562171167, 0.0,0.005};
    Point(10) = {0.9, 0.013352458679209828, 0.0,0.005};
    Point(11) = {1.0, 1.650594053104193e-17, 0.0,0.005};
    Point(12) = {0.9, -0.013352458679209828, 0.0,0.005};
    Point(13) = {0.8, -0.025211311562171167, 0.0,0.005};
    Point(14) = {0.7, -0.03570927685952479, 0.0,0.005};
    Point(15) = {0.6, -0.04479110070446828, 0.0,0.005};
    Point(16) = {0.5, -0.05219019673131475, 0.0,0.005};
    Point(17) = {0.4, -0.05738266105317275, 0.0,0.005};
    Point(18) = {0.30000000000000004, -0.05948422462775666, 0.0,0.005};
    Point(19) = {0.19999999999999996, -0.05696855715076947, 0.0,0.005};
    Point(20) = {0.09999999999999998, -0.046561895043862704, 0.0,0.005};

The syntax is `Point(i) = {x, y, z, mesh_size};` where `i` is a unique
index of the point, `x`, `y` and `z` are the coordinates and `mesh_size`
is the desired mesh size at this point. Pasting this output into a file
called `aerofoil.geo` (or setting the script up to write its output to
that file like in the [final version](case/mesh_generation.jl) and
running `gmsh aerofoil.geo` will prompt you with the following:

![Profile points](images/raw_profile.png)

The next critical step is to connect all the points with a spline. The
profile points should be connected with a single spline instead of a set
of hundreds of single lines since this will later enable us to name the
aerofoil surface. This is done by the following code:

``` julia
println(io,"""Spline(1)={1:$n_aerofoil_points,1};""")
```

    Spline(1)={1:20,1};

The syntax is `Spline(i)={p1,p2,...pk};` where `i` is a unique index of
the spline and `pi` are the indices of the points the spline should
connect. `pi:pj` is a shorthand for `pi,pi+1,...,pj`. The `1` at the end
of the line is the first index again, which is needed to close the
spline. The result is the following:

![Profile with spline](images/splined_profile.png)

### Generating the bounding box

The next step is to generate the bounding box. This is done by the
following code:

``` julia
bounding_radius=5.0
far_field_mesh_size=0.3
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
```

    Point(21) = {0.0, 5.0, 0.0, 0.3};
    Point(22) = {0.0, -5.0, 0.0, 0.3};
    Point(23) = {-5.0, 0.0, 0.0, 0.3};
    Point(24) = {5.0, 5.0, 0.0, 0.3};
    Point(25) = {5.0, -5.0, 0.0, 0.3};
    Circle(21)= {22, 1, 23};
    Circle(22)= {23, 1, 21};
    Line(23) = {21, 24};
    Line(24) = {24, 25};
    Line(25) = {25, 22};

You can look up the exact syntax of the commands in the [Gmsh
documentation](https://gmsh.info/doc/texinfo/gmsh.html). The result is
the following:

![Profile with bounding box](images/bounding_box_2d.png)

Next, we want to create a surface that fills the area between the
aerofoil and the bounding box. This is done by the following code:

``` julia
println(io,"Curve Loop(2) = {$(n_aerofoil_points+1):$(n_aerofoil_points+5)};")
println(io,"Curve Loop(3) = {1};")
println(io,"Plane Surface(1) = {2,3};")
```

    Curve Loop(2) = {21:25};
    Curve Loop(3) = {1};
    Plane Surface(1) = {2,3};

We join a set of lines to a loop with `Curve Loop(i) = {p1,p2,...pk};`
where `i` is a unique index of the loop and `pi` are the indices of the
lines the loop should connect. Loop `2` is the bounding box and loop `3`
is the aerofoil. We then join the loops to a surface with
`Plane Surface(i) = {l1,l2,...lk};` where `i` is a unique index of the
surface and `li` are the indices of the loops the surface should
connect. This does not make a visual difference.

### Extruding the geometry

OpenFoam does not allow us to use 2D geometries, so we need to extrude
the geometry in the z-direction. This is done by the following code:

``` julia
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
""")
```

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

We extrude in the direction of the vector `{0,0,meshThickness}` with
`Extrude {0, 0, meshThickness} {Surface{1};Layers{1};Recombine;};`.
`Surface{1};` tells `gmsh` we want to extrude the surface with the index
one we just created. The `Layers{1}` command tells Gmsh to only generate
one mesh layer. The `Recombine` command does something I do not
understand but is recommended in other tutorials.

Finally, we need to assign names to surfaces in order to be able to
later set boundary conditions in OpenFoam. The keyword `Physical` means
that a name needs to be exported to the mesh. The syntax is
`Physical Surface{"name_i_choose"}={p1,p2,...pk};` where `p1,p2,...pk`
are the indices of the surfaces we want to assign the name to. The same
holds for volumes. The names we choose are `frontAndBackPlanes`,
`INLET`, `OUTLET`, `AIRFOIL` and `WALL`. The names are not important,
but they need to be consistent with the names we use in OpenFoam. The
`Extrude` command returns a list of surfaces it created by the extrusion
as well as the volume it created. The ordering of these values is
described by the
[docs](https://gmsh.info/doc/texinfo/gmsh.html#Extrusions) as follows:

> By default, the list contains the “top” of the extruded entity at
> index 0 and the extruded entity at index 1, followed by the “sides” of
> the extruded entity at indices 2, 3, etc.

Now you see why it is important the aerofoil consists of only one loop:
Else we would have to assign a few hundred surfaces to a physical
surface now. Even now the assignment is not trivial, but you can either
try to keep track of the order in which the lines were added to the
extrusion or use the visibility tool in `gmsh`, go to the tree view,
select only one physical surface and click `Apply`. This will show you
if you assigned the physical surface to the correct surfaces.

# Results

``` julia
using DataFrames,CSV
liftData=CSV.read("case/allResults.dat",DataFrame,header=false)[:,[3,4]]|>Matrix
tangentCoeffs=liftData[:,1]
normalCoeffs=liftData[:,2]
angles=[0.001,5,10,15,20]
using Plots
liftCoeffs=cos.(angles).*normalCoeffs.+sin.(angles).*tangentCoeffs
plot(angles,normalCoeffs)
```

![](index_files/figure-markdown_strict/cell-7-output-1.png)
