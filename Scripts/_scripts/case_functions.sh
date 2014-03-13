#!/bin/bash

# The calling script could be wanting to run in either parallel or a single
# threaded solve operation, all you need to do is add functions runParallel
# and runSingle respectively. It is possible that they are very similar, so
# the functions could just set-up the case and then go into a common section
# this is just the entry point which is 'required'. Further, Allrun and
# Allclean has been put into this one file - it isn't really needed to have
# two different files; this also simplifies things through just having less
# files to copy from case to case

if [ -z "${PBS_O_HOME+xxx}" -o -z "${PBS_O_WORKDIR+xxx}" ]; then
    echo "Running on a local machine (PBS variables not set)"
    export PBS_O_HOME=$HOME
    export PBS_O_WORKDIR=`pwd`
fi

export _logdir=$PBS_O_WORKDIR/logs
export mpirun=/pkg/suse11/openmpi/1.6.5/bin/mpirun

_false=1
_true=0

function loadOF {
    module load gcc      > /dev/null 2>&1
    module load cmake    > /dev/null 2>&1
    module load openmpi  > /dev/null 2>&1
    module load mpi      > /dev/null 2>&1
    module load intel    > /dev/null 2>&1
    module load scotch   > /dev/null 2>&1
    module load openfoam > /dev/null 2>&1
    echo "Loaded OpenFOAM"
}

function runApplication {
    echo "Running $*"
    $* | tee -a $_logdir/log.$1
}

function cleanCase {
    echo "Cleaning Case"
    mkdir -p .delete 2> /dev/null
    mv processor* .delete 2> /dev/null
    rm -rf .delete > /dev/null 2>&1 & 
    $_script/Allclean.sh
}

function getApplication {
    application=$(sed -ne 's/^application *\(.*\);/\1/p' system/controlDict)
}

function getNCPU {
    _NCPU=$(sed -ne 's/^numberOfSubdomains *\(.*\);/\1/p' system/decomposeParDict)
}

function getDecomposeParameters {
    _NXM=$(echo $1 | grep -o "[0-9]*x[0-9]*")
    N=$(echo $_NXM | cut -d'x' -f1)
    M=$(echo $_NXM | cut -d'x' -f2)
    _NCPU=$(( $N*$M ))
}

function setCFDRuntimeParameters {
    # Set CFD runtime parameters, the runCFD file has been
    #  copied into the pbs work directory, now we are changing
    #  variables memory, time and name

    cfd_mem=$(grep "cfd_mem" thisCase | cut -d '=' -f2 | tr -d ' ')
    cfd_time=$(grep "cfd_time" thisCase | cut -d '=' -f2 | tr -d ' ')
    cfd_name=$(grep "cfd_name" thisCase | cut -d '=' -f2 | tr -d ' ')   
    foam_load=$(grep "foam_load" thisCase | cut -d '=' -f2)   
 
    if [[ ! $cfd_mem = "" ]]; then
        sed -i "s/mem=5000mb/mem=$cfd_mem/" runCFD
        echo "Running CFD with $cfd_mem of ram"
    fi

    if [[ ! $cfd_time = "" ]]; then
        sed -i "s/walltime=05:00:00/walltime=$cfd_time/" runCFD
        echo "Running CFD for $cfd_time"
    fi
    
    if [[ $cfd_name = "" ]]; then
        cfd_name=$(basename $(pwd) | cut -c 1-15)
    fi

    sed -i "s/N runcfd/N $cfd_name/" runCFD

    if [[ ! $foam_load = "" ]]; then
        echo "$foam_load"
        sed -i "s|loadOF|$foam_load|" runCFD
    fi
}

function checkFileContains {
    line_count=$(grep "$2" $1 | wc -l)
    if [ $line_count == 0 ]; then
        return 1
    else
        return 0
    fi
}

function thisCaseHas {
    if [ -e thisCase ]; then
        if checkFileContains thisCase "function $1" ; then
            return $_true
        else
            return $_false
        fi
    else
        return $_false
    fi
}
