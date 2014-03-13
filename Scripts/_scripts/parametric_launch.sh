#!/bin/bash

# Expects folder name as P1-2-5_R-10-20
#  aka P1-lower-upper R-lower-upper

parametric_range=$(basename $(pwd))
P1=$(echo $parametric_range | cut -d '_' -f1)
P1_name=$(echo $P1 | cut -d '-' -f1)
P1_lower=$(echo $P1 | cut -d '-' -f2)
P1_upper=$(echo $P1 | cut -d '-' -f3)

P2=$(echo $parametric_range | cut -d '_' -f2)
P2_name=$(echo $P2 | cut -d '-' -f1)
P2_lower=$(echo $P2 | cut -d '-' -f2)
P2_upper=$(echo $P2 | cut -d '-' -f3)

P3=$(echo $parametric_range | cut -d '_' -f3)
P3_name=$(echo $P3 | cut -d '-' -f1)
P3_lower=$(echo $P3 | cut -d '-' -f2)
P3_upper=$(echo $P3 | cut -d '-' -f3)

echo "$P1_name Range" $P1_lower $P1_upper
echo "$P2_name Range" $P2_lower $P2_upper
echo "$P3_name Range" $P3_lower $P3_upper

function launchCase {
    new_name=$1
    if [ ! -d $new_name ]; then
        echo "/------------------------------------------------------------------------------\\"
        echo "                            Creating case $new_name"
        echo "Duplicating _setup case"
        cp -r _setup $new_name
        cd $new_name
        mkdir -p logs
        runParallel_5x1 start | tee logs/log.start
        cd ..
        echo "\\------------------------------------------------------------------------------/"
        echo
    fi
}


function launchParametric {
    
    if [[ $P1_lower == "FILE" ]]; then
        P1_range=$(cat $P1_upper)
    elif [[ ! $P1_name == "" ]]; then
        P1_range=$(seq $P1_lower $P1_upper)
    else
        P1_range="skip"
    fi

    if [[ $P2_lower == "FILE" ]]; then
        P2_range=$(cat $P2_upper)
    elif [[ ! $P1_name == "" ]]; then
        P2_range=$(seq $P2_lower $P2_upper)
    else
        P2_range="skip"
    fi

    if [[ $P3_lower == "FILE" ]]; then
        P3_range=$(cat $P3_upper)
    elif [[ ! $P3_name == "" ]]; then
        P3_range=$(seq $P3_lower $P3_upper)
    else
        P3_range="skip"
    fi

    for _P1 in $P1_range; do
        for _P2 in $P2_range; do
            for _P3 in $P3_range; do
                new_name=$P1_name"-"$_P1

                if [[ ! $P2_name == "" ]]; then
                    new_name=$new_name"_"$P2_name"-"$_P2
                fi

                # Quirk in an old case
                if [ ! $_P3 = 20 ]; then
                    if [[ ! $P3_name == "" ]]; then
                        new_name=$new_name"_"$P3_name"-"$_P3
                    fi
                fi

                launchCase $new_name
           done
        done
    done
    

 #   for ((_P1=P1_lower;_P1<=P1_upper;_P1++)); do
 #       for ((_P2=P2_lower;_P2<=P2_upper;_P2++)); do
 #           for ((_P3=P3_lower;_P3<=P3_upper;_P3++)); do

}

function getScores {
    # Get scores, using grep so you can narrow down the cases you want to work on
    echo "Getting scores in directories matching grep \"$1\""
    folder_list=$(ls | grep "$1")
    
    # Rotate only if we don't already have a backup (killed early)
    if [ -e scores.tmp ]; then
        mv scores scores.tmp 2> /dev/null # Rotate scores file
    fi
    
    rm clocktime incomplete yplusmax_average Cp_in_out 2> /dev/null # Just delete all other score files
    
    for D in $folder_list; do
        if [ -d "${D}" ] && [ -d "${D}/logs" ]; then
            if [ -e "${D}/logs/log.python3" ]; then
                sf_result=$(tail "$D/logs/log.simpleFoam" -n 3 | grep "End" | wc -l)
                
                if [ $sf_result == 0 ]; then
                    echo "$D has not finished" | tee -a incomplete
                else
                    score=$(tail -n 1 "$D/logs/log.python3")
                    echo $D": "$score | tee -a "scores"
                    
                    clocktime=$(tail $D/logs/log.simpleFoam -n 8 | head -n1 | sed "s/ //g" | cut -d '=' -f3)
                    echo $D": "$clocktime | tee -a "clocktime"
                    
                    yplusmax=$(grep -o "max: [0-9.]*" $D/logs/log.yPlusRAS)
                    yplusmax=$(echo $yplusmax | sed "s/ //g" | sed "s/max//g")
                    yplus1=$(echo $yplusmax | cut -d ":" -f2)
                    yplus2=$(echo $yplusmax | cut -d ":" -f3)
                    yplus3=$(echo $yplusmax | cut -d ":" -f4)
                    yplus4=$(echo $yplusmax | cut -d ":" -f5)
                    yplusma=$(echo "scale=4;($yplus1+$yplus2+$yplus3+$yplus4)/4" | bc)
                    echo $D": "$yplusma | tee -a "yplusmax_average"
                    
                    latest=$(foamListTimes -case $D  -latestTime)
                    #cp_n025=$(cat postProcessing/sets/$latest/Cp_Z_k_p.xy | head -n1 | sed "s/\t/_/g" | sed "s/ //g" | cut -d '_' -f3)
                    cp_p434=$(cat $D/postProcessing/sets/$latest/Cp_Z_k_p.xy | tail -n1 | sed "s/\t/_/g" | sed "s/ //g" | cut -d '_' -f3)
                    cp_in_out=$(echo "scale=4;-($cp_p434 / (0.5 * 11.6 * 11.6))" | bc)                   
                    echo $D": "$cp_in_out | tee -a "Cp_in_out"
                fi
                
                echo
            fi
        fi
    done
    
    new_cases=$(diff scores scores.tmp | wc -l)
    if [ $new_cases == 0 ]; then
        echo "No more cases have completed"
    else
        echo "There are new scores!"
        echo
        diff scores scores.tmp
    fi
    
    rm scores.tmp
}

function updateSystem {
    read -p "Do you want to TOTALLY replace $1 in EVERY case? " -n 1 -r
    echo #newline after input is complete
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for D in *; do
            if [ -d "${D}" ] && [ -d "${D}/logs" ] && [ -e "${D}/$1" ]; then
                echo "Replacing $D/$1"
                cp _setup/$1 $D/$1
            fi
        done
    fi
}

function runCommand {
    read -p "Do you want to MANUALLY run $* for EVERY case? " -n 1 -r
    echo #newline after input is complete
    if [[ $REPLY =~ ^[Yy]$ ]]; then   
        for D in *; do
            if [ -d "${D}" ] && [ -d "${D}/logs" ]; then
                echo "/------------------------------------------------------------------------------\\"
                echo "                            Running $1 in $D"
                cd $D
                $*
                cd ..
                echo "\\------------------------------------------------------------------------------/"
                echo
            fi
        done
    fi
}

function restart {
    # Get scores, using grep so you can narrow down the cases you want to work on
    echo "Restarting cases in directories matching grep \"$1\""
    folder_list=$(ls | grep "$1")
    
    for D in $folder_list; do
        if [ -d "${D}" ] && [ -d "${D}/logs" ]; then
            if [ ! -e "${D}/logs/log.python3" ]; then
                echo "/------------------------------------------------------------------------------\\"
                cd $D
                
                if [ ! -e "logs/log.simpleFoam" ]; then
                    # postProcessing didn't run because simpleFoam has not run (killed before ran)
                    echo "                        Case $D has not been run"
                    runParallel_5x1 start | tee logs/log.start
                else
                    # Check if simpleFoam ended to determine the next step
                    sf_result=$(tail "logs/log.simpleFoam" -n 3 | grep "End" | wc -l)
                    
                    if [ $sf_result == 0 ]; then
                        # postProcessing didn't run as simpleFoam started but didn't finish (jobs killed during run)
                        echo "                     simpleFoam did not finish for case $D"
                        read -p "Do you want to rerun runParallel_5x1 runCFD? " -n 1 -r
                        echo #newline after input is complete
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            # Yes, run simpleFoam
                            runParallel_5x1 runCFD
                        fi
                    else
                        # postProcessing didn't run but simpleFoam has run (postProcessing ran out of memory?)
                        echo "                 Rerunning postProcessing step for $D"
                        qsub ../_scripts/run_post.sh
                    fi
                fi
                
                cd ..
                echo "\\------------------------------------------------------------------------------/"
                echo
            fi
        fi
    done

}

function whoops {
    unalias qstat
    
    read -p "Do you want to kill every job? " -n 1 -r
    echo

    my_jobs=$(qstat -u `whoami`)
    for job in $my_jobs; do
        if [[ $job =~ ".pbsserv" ]]; then
            job_number=$(echo $job | cut -d '.' -f1)
            job_detail=$(qstat -f $job_number)
            has_depends=$(echo $job_detail | grep "depend = after" | wc -l)
            if [ ! has_depends = 1 ] || [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Killing $job_number"
                #qdel $job_number
            fi
        fi
    done
}

option=$1
shift

case $option in   
    start) launchParametric;;
    scores) getScores $*;;
    restart) restart $*;;
    updateSystem) updateSystem $1;;
    runCommand) runCommand $*;;
    whoops) whoops;;
    *) echo "You can either start or get scores"
esac
