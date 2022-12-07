#!/bin/bash
source /opt/OpenFOAM/OpenFOAM-10/etc/bashrc
foamDictionary 0/U -entry angle -set $1
./Allclean
./Allrun
if [[ -z "${SILENT}" ]]; then
    paraFoam -builtin
fi