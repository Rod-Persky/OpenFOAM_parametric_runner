#!/bin/bash -l
#PBS -N thisCase
#PBS -l nodes=1:ppn=1
#PBS -l mem=100mb
#PBS -l walltime=00:10:00
#PBS -j oe
#PBS -o logs/pbs.thisCase
#PBS -r n

blockMesh=constant/polyMesh/blockMeshDict.m4

# Parameters expecting G-x_R-y as folder name
parametric_name=$(echo $(basename $(pwd)))
G=$(echo $parametric_name | cut -d '_' -f1 | cut -d '-' -f2)
R=$(echo $parametric_name | cut -d '_' -f2 | cut -d '-' -f2)


function preMesh {

if [ -e constant/polyMesh/blockMeshDict.m4.bak ]; then
    echo "Restoring blockmesh"
    cp $blockMesh.bak $blockMesh
else
    echo "Backing up blockmesh"
    cp $blockMesh $blockMesh.bak
fi

cells_r_def="m4_define(rNumberOfCells,"
sed -i "s/$cells_r_def 15)/$cells_r_def $R)/" $blockMesh

cells_Gr_def="m4_define(rGrading,"
sed -i "s/$cells_Gr_def 5)/$cells_Gr_def $G)/" $blockMesh

}


case $1 in
    preMesh) preMesh;;
    *) echo "$1 is not required by this case";;
esac








# Case Customisation,
#  In this script we customise the case, you do whatever is needed
#  except it is generally single threaded - this will usually allow
#  you to:
#  - Change mesh parameters
#  - Do mesh refinement
#
#  Do not do anything else here, we can automatically detect if you
#  were wanting to run parallel! Indeed you can even delete this file
#  if you don't need to do anything more to the case after setting
#  it up
#
#  This file is however called a number of times, so there is a requisite
#  amount of barrier that needs to be placed if using this file. You'll
#  need a case statement that can deal with the following $1 options:
#  - premesh
#  - postmesh
#
#  Of course you can have the *) echoing that the function is not required.