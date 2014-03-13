#!/bin/bash -l
#PBS -N setup
#PBS -l nodes=1:ppn=1
#PBS -l mem=500mb
#PBS -l walltime=00:02:00
#PBS -j oe
#PBS -o logs/pbs.setup
#PBS -r n

# Setup,
#  This script is the first to run, it:
#  - Sets up the Geometry
#  - Creates the initial mesh
#  - Adds initial fields
#
# These functions are intended to be general to the whole case,
# such that no editing is necessary in this file. Customisation is
# implemented via a callback to thisCase which has $1 of either
# premesh or postmesh.

# Load functions and variables
cd $PBS_O_WORKDIR
_script=$PBS_O_WORKDIR/../_scripts
. $_script/case_functions.sh

blockMeshDict="constant/polyMesh/blockMeshDict"

loadOF

# First callback, does your case require any premesh modification?
#  such as changing the m4 parameters (which is pretty standard)
./thisCase preMesh

# Start Processing,
echo "Running M4"
m4 -P "$blockMeshDict.m4" > $blockMeshDict

cp -Lr 0_orig 0
runApplication blockMesh
runApplication checkMesh

./thisCase postMesh

runApplication addSwirlAndRotation
