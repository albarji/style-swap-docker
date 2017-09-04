#!/bin/bash

#
# Entrypoint script to style algorithm
#

# Process params so that references to inputs are located in the mounted /images directory
procparams=""
savefolder="/images"
while [ "$1" != "" ]; do
    option="$1"
    case ${option} in
       "--style"|"--content"|"--contentBatch")
        shift
        procparams="${procparams} ${option} /images/${1}"
        ;;
       "--save")
        shift
        savefolder="/images/${1}"
        ;;
       *)
        procparams="${procparams} ${option}"
        ;;
    esac
    shift
done

# Call main application with processed paremeters
th /style-swap/style-swap.lua --save ${savefolder} ${procparams}
