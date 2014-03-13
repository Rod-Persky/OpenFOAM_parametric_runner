#!/bin/bash
# runCase,
# This file is the main driver of the cases, it will setup the problem to
# be run on PBS step by step. It loads in the various scripts and queues them.


_script=../_scripts
. $_script/case_functions.sh
cd $PBS_O_WORKDIR

function baseSetup {
    # Step 1, Setup the case
    step_1=$(qsub $_script/setup.sh) 
    echo "Running setup on $step_1"
}

function caseSetup {
    # Step 2, If there is a thisCase
    if thisCaseHas customisation ; then
        step_2=$(qsub -W depend=afterany:$step_1 thisCase customisation)
        echo "Running customisation script on $step_2"
        echo "Case customisation ($step_2) is waiting on $step_1"
    else
        echo "thisCase does not contain a customisation function"
        step_2=$step_1
    fi
}

function run_decompose {
    # Step 3, Everything should be setup now so finally
    #  we decompose if necessary and then run the case. First
    #  lets get a clean copy of runCFD.
    cp $_script/run_cfd.sh runCFD
    
    # Replace time and memory limits with that in the thisCase file
    if [ -e thisCase ]; then
        echo "Setting CFD Runtime Parameters"
        setCFDRuntimeParameters      
    fi

    # Check if the case is running in parallel and decompose
    if [[ $(basename $0) =~ Parallel ]]; then
        echo "Setting up parallel decomposition"
        $_script/decompose.sh setup $(basename $0)
        step_3=$(qsub -W depend=afterany:$step_2 $_script/decompose.sh)
    else
        echo "No parallelism detected, it's specified though naming of this file to runParallel_nxm"
        step_3=$step_2
    fi
    echo "Decomposition step ($step_3) is waiting on $step_2"
}

function run_cfd {
    step_4=$(qsub -W depend=afterany:$step_3 runCFD)
    echo "CFD ($step_4) is waiting on $step_3"
}

function run_post {
    step_5=$(qsub -W depend=afterany:$step_4 $_script/run_post.sh)
    echo "Postprocessing will begin once $step_4 has finished"
}

mkdir -p $_logdir    


case $1 in
    start) 
             cleanCase
             baseSetup
             caseSetup
             run_decompose
             run_cfd
             run_post;;
    runCFD)  run_cfd
             run_post;;
    stop)  foamEndJob -c;;
    *)     echo "o hai there";;
esac
