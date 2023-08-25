#!/bin/bash

SECONDS=0

# Get the directory of the script itself
BaseDir=$(dirname "$(realpath "$0")")

# Load variables file
source $BaseDir/config.cfg

# Load functions
source $BaseDir/Functions.sh

LogDir="$WorkingDir/$User/$1/Logs"

# Create Log file
create_log "$1"



config_file=$(create_temp_config "$BaseDir/tmp.cfg")
add_config_item "$BaseDir/tmp.cfg" "LOG_FILE"

# Set up output redirection to log file
#exec > >(tee -a "$LOG_FILE") 2>&1

write_log $DEBUG  "~~~~~~~~~ Fix EXIF data & move images & videos to Media Folder Script ~~~~~~~~~"
write_log $DEBUG  "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Version: $version ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 


# Check the argument and execute the corresponding script with the remaining arguments
if [ "$1" = "CopyPics" ]; then
    $BaseDir/CopyPics.sh "${@:2}"  # Pass remaining arguments to script1.sh
elif [ "$1" = "script2" ]; then
    ./script2.sh "${@:2}"  # Pass remaining arguments to script2.sh
elif [ "$1" = "script3" ]; then
    ./script3.sh "${@:2}"  # Pass remaining arguments to script3.sh
else
    echo "Invalid argument. Please provide a valid script name."
fi



# Cleanup

#rm "$BaseDir/tmp.cfg"

duration=$SECONDS
write_log $DEBUG "Total time $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
write_log $DEBUG "Program has finished: Goodbye!"