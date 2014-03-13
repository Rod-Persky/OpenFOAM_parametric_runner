#!/bin/bash -l
#PBS -N runpost
#PBS -l nodes=1:ppn=1
#PBS -l mem=5000mb
#PBS -l walltime=00:10:00
#PBS -j oe
#PBS -o logs/pbs.runPOST

# runPOST,
#  This script:
#  - Reconstructs if the case was run in parallel
#  - Samples the latest time
#  - Generates yPlusRAS field for latest time
#  - Calculates the error for latest time (python script)

# Setup the required workspace variables
cd $PBS_O_WORKDIR
_scripts=../_scripts
. $_scripts/case_functions.sh

loadOF

# Reconstruct latest time if were using parallel
if [ -e system/decomposeParDict ]; then
    runApplication reconstructPar -latestTime
fi

runApplication sample -latestTime
runApplication yPlusRAS -latestTime

# To get python3
source $PBS_O_HOME/.bashrc

cd postProcessing
ln -s ../../_scripts/check/* .
runApplication python3 getError.py