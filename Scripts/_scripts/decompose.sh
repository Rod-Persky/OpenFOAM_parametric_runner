#!/bin/bash -l
#PBS -N decompose
#PBS -l nodes=1:ppn=1
#PBS -l mem=2000mb
#PBS -l walltime=00:10:00
#PBS -j oe
#PBS -o logs/pbs.decompose
#PBS -r n

# Decompose,
#  This script:
#  - Sets up the decomposition, and
#  - Runs the decomposition.
#
#  To setup the decomposition it's expected that setup nxm will be sent where
#  n is the cpus per machine and m is number of machines.


cd $PBS_O_WORKDIR
_script=../_scripts
. $_script/case_functions.sh


function setup {
    # Parameter 1: basename of running file (e.g runParallel_nxm
    # Isolate NxM, cut each out, multiply, copy decompose and replace
    getDecomposeParameters $1
    echo "setting up for $_NCPU CPUs ($N cores over $M node/s)"
    
    # Copy decomposeParDict and replace the numbers with the given parameters
    cp $_script/decomposeParDict system
    sed -i "s/OfSubdomains/OfSubdomains $_NCPU/" system/decomposeParDict
    sed -i "s/\#PBS -l nodes=1:ppn=1/\#PBS -l nodes=$M:ppn=$N/" runCFD
}

function runDecompose {
    loadOF
    runApplication decomposePar -ifRequired
}

case $1 in
    setup) setup $2;;
    *) runDecompose;;
esac
