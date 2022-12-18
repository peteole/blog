#!/bin/bash
source /opt/OpenFOAM/OpenFOAM-10/etc/bashrc
julia structured_mesh_generation.jl
gmsh -3 aerofoil_str.geo -format msh2
gmshToFoam aerofoil_str.msh
function setBoundaryType {
    foamDictionary constant/polyMesh/boundary -entry entry0/$1/type -set $2
    #foamDictionary constant/polyMesh/boundary -entry entry0/$1/physicalType -set $3
}
setBoundaryType frontAndBackPlanes empty
setBoundaryType AIRFOIL wall