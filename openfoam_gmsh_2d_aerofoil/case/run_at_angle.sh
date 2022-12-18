#!/bin/bash
cd "$(dirname "$0")"
echo "Running airfoil simulation at $1 degrees at location $(pwd)"
source /opt/OpenFOAM/OpenFOAM-10/etc/bashrc
foamDictionary 0/U -entry angle -set $1
./Allclean
./Allrun
if [[ -z "${SILENT}" ]]; then
    paraFoam -builtin
fi