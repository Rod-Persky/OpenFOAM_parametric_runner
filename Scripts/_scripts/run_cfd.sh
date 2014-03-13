#!/bin/bash -l
#PBS -N runcfd
#PBS -l nodes=1:ppn=1
#PBS -l mem=5000mb
#PBS -l walltime=05:00:00
#PBS -j oe
#PBS -o pbs.runCFD

# runCFD,
#  This script:
#  - Figures out what application is being used
#  - If its running ST or MT
#  - Sets it going
#
#  This script should probably keep a look out on how time is progressing and
#  stop the run before it gets dumped by PBS. Do not modify the pbs variables
#  in this file, they can be modified in your thisCase file - the 5GB is a good
#  starting point for cases up to 6 Million nodes!

# Setup the required workspace variables
cd $PBS_O_WORKDIR
_script=../_scripts
. $_script/case_functions.sh

# Get CFD information
getApplication
loadOF

# If decomposeParDict exists then we're using parallel processing
if [ -e system/decomposeParDict ]; then
    getNCPU
    mpirun="$mpirun --hostfile $PBS_NODEFILE -np $_NCPU"
    $mpirun $application -parallel >> $_logdir/log.$application 2>&1
else
    runApplication $application
fi
