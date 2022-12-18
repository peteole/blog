#!/bin/bash
fluentMeshToFoam /home/olep/Documents/Studium/Semester5/CFD/Coursework/Mesh-2D/$1
sed -i 's/0.09626306315)/0.5)/g' constant/polyMesh/points
./set_config_property.sh name "fluent_$1"
./write_mesh_properties.sh