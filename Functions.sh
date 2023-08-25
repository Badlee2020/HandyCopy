#!/bin/bash

#############################################################################
# Function name: write_log
# Purpose: To write logs to a specified log file.
# Parameters: 
#   1) Log level for the message (DEBUG, INFO, WARN, ERROR)
#   2) Log message
#
# Usage: 
#   write_log "INFO" "This is an info log."

write_log() {
  
  # Retrieve the first argument passed to the function, which is the log level.
  local log_level="$1"
  
  declare -A log_levels=( ["DEBUG"]=0 ["INFO"]=1 ["WARN"]=2 ["ERROR"]=3 )

  # If the log level of the message is less than the global minimal log level, return
  if [[ ${log_levels[$log_level]} < ${log_levels[$MIN_LEVEL]} ]]; then
    return
  fi

  # 'shift' is a shell built-in command that shifts positional parameters to the left.
  # Here, it's used to remove the first argument (log level) so that "$*" 
  # can represent the whole log message.
  shift 
  
  # Get the log message. After shift, "$*" will contain all the arguments passed after log level.
  local message="$*"
  
  # Get the current date and time in the format "YYYY-MM-DD HH:MM:SS".
  LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Write the log message to the log file. The format is:
  # [Date and Time] - [Log Level]: [Log Message]
  # The ">>" operator appends the log message to the end of the $LOG_FILE.
  echo "${LOGTIME} - ${log_level}: ${message}" >> $LOG_FILE
}

#############################################################################
# Function name: send_notification
# Purpose: Sends a notification via an HTTP request.
# Parameters:
#   1) Title of the notification
#   2) Priority of the notification
#   3) Tags associated with the notification
#   4) Actual message of the notification
#
# Usage:
#   send_notification "Alert" "High" "server,alert" "Disk space running low!"

send_notification() {
    # Retrieve the first argument passed to the function, which is the title.
    title="$1"
    
    # Retrieve the second argument, which represents the priority.
    priority="$2"
    
    # Retrieve the third argument, which represents the tags.
    tags="$3"
    
    # Retrieve the fourth argument, which is the main message content.
    message="$4"

    # Use the curl command to send an HTTP POST request.
    # -H specifies headers for the HTTP request. Here, we send the title, priority, and tags as headers.
    # -d specifies the data or payload for the POST request, which is the message in this case.
    # The endpoint URL "ntfy.cellophaneslinger/Synology" seems to be a hypothetical or custom endpoint 
    # where the notification data is sent.
    curl \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        -d "$message" \
        ntfy.cellophaneslinger/Synology
}

#############################################################################
# Function name: update_exiftool
# Purpose: Checks for the latest version of exiftool on GitHub and updates it if necessary.
# This function checks for updates at most once every 7 days.
#
# Usage: 
#   update_exiftool

update_exiftool() {
  # Define the file path where the last check date is stored
  LAST_CHECK_FILE=$BaseDir"/last_exiftool_check.txt"

  # If the last check file doesn't exist, create it with a very old date to ensure a check happens.
  if [ ! -f $LAST_CHECK_FILE ]; then
    echo "2000-01-01" > $LAST_CHECK_FILE
  fi

  # Read the date of the last check from the file
  LAST_CHECK_DATE=$(cat $LAST_CHECK_FILE)

  # Get the current date in the format "YYYY-MM-DD"
  CURRENT_DATE=$(date "+%Y-%m-%d")

  # Calculate the difference between the current date and the last check date in seconds.
  # If the difference is greater than or equal to 604800 seconds (7 days), proceed with the check.
  if [ $(($(date -d $CURRENT_DATE +%s) - $(date -d $LAST_CHECK_DATE +%s))) -ge 604800 ]; then

    # Fetch the latest version tag of exiftool from its GitHub repo using the GitHub API
    latest_version=$(curl --silent "https://api.github.com/repos/exiftool/exiftool/tags" | jq -r '.[].name' | sort -V | tail -n 1)
    
    # If fetching the version failed or returned an empty string, log the error and exit.
    if [ -z "$latest_version" ]; then
      write_log $DEBUG "Could not fetch the latest version of exiftool. Exiting the update function."
      return 1
    fi

    # Get the current version of exiftool installed on the system.
    current_version=$(perl $ExifDir/exiftool -ver)

    # If the current version differs from the latest version, update is needed
    if [ "$current_version" != "$latest_version" ]; then
      write_log $DEBUG "Updating exiftool to version $latest_version"
      
      # Download the latest version of exiftool from GitHub
      wget https://github.com/exiftool/exiftool/archive/refs/tags/${latest_version}.tar.gz -P $BaseDir

      # If the download fails, log the error and exit.
      if [ $? -ne 0 ]; then
        write_log $DEBUG "Failed to download the latest version of exiftool. Exiting the update function."
        return 1
      fi

      # Remove the existing exiftool directory and create a new one
      rm -rdf $ExifDir
      mkdir $ExifDir

      # Extract the downloaded tar.gz file into the new directory
      tar -xzf $BaseDir/${latest_version}.tar.gz -C $ExifDir --strip-components=1

      # If the extraction fails, log the error, remove the downloaded file, and exit.
      if [ $? -ne 0 ]; then
        write_log $DEBUG "Failed to extract the latest version of exiftool. Exiting the update function."
        rm $BaseDir/${latest_version}.tar.gz
        return 1
      fi
      
      # Remove the downloaded tar.gz file after extraction
      rm $BaseDir/${latest_version}.tar.gz
    
    else
      write_log $DEBUG "exiftool is already up-to-date"
    fi

    # After checking (and potentially updating), record the current date as the last check date.
    echo $CURRENT_DATE > $LAST_CHECK_FILE
  fi
}

#############################################################################
# Function name: check_directory_exists_or_create
# Purpose: Check if a specified directory exists. If not, and if permission is granted, create it.
# Parameters:
#   1) dir: The directory path to check or create.
#   2) can_create: A boolean (true/false) that indicates whether the directory can be created if it doesn't exist.
#
# Usage: 
#   check_directory_exists_or_create "/path/to/directory" true
#   check_directory_exists_or_create "/path/to/directory" false

check_directory_exists_or_create() {
    # Retrieve the first argument passed to the function, which represents the directory path.
    local dir=$1
    
    # Retrieve the second argument, which indicates whether the directory can be created if it doesn't exist.
    local can_create=$2

    # Check if the directory does not exist.
    if [ ! -d "$dir" ]; then
        
        # If creating the directory is permitted
        if [ "$can_create" = true ]; then
            
            # Try to create the directory, including any necessary parent directories.
            mkdir -p "$dir"
            
            # Check if the directory creation was successful.
            if [ $? -eq 0 ]; then
                # If successful, log a debug message.
                write_log $DEBUG "Directory $dir was not found and has been created."
            else
                # If unsuccessful, log an error and terminate the script.
                write_log $ERROR "Failed to create directory $dir."
                exit 1
            fi
            
        else
            # If directory creation isn't permitted, log an error and terminate the script.
            write_log $ERROR "Directory $dir does not exist."
            exit 1
        fi
        
    else
        # If the directory already exists, log a debug message.
        write_log $DEBUG "Directory $dir exists."
    fi
}

#############################################################################
# Function name: create_log
# Purpose: Creates a log file with a specific name format and redirects standard output and standard error to this log file.
# Parameters:
#   1) log_name: A string that will be used as a part of the log file name after sanitization.
#
# Usage: 
#   create_log "SpecificEventName"
#
# Note: It relies on global variables $LogDir and $LogBase. $LogDir is assumed to be the path to the directory where logs should be saved,
# and $LogBase is a base name that gets included in every log file name.

# Function name: create_log
# Purpose: Creates a log file with a specific name format and redirects standard output and standard error to this log file.
# Parameters:
#   1) log_name: A string that will be used as a part of the log file name after sanitization.
#
# Usage: 
#   create_log "SpecificEventName"
#
# Note: It relies on global variables $LogDir and $LogBase. $LogDir is assumed to be the path to the directory where logs should be saved,
# and $LogBase is a base name that gets included in every log file name.

create_log() {
  # Retrieve the log name from the first argument.
  local log_name=$1

  # Validate that a log name was provided.
  if [[ -z $log_name ]]; then
    echo "Error: No log name provided."
    return 1
  fi
  
  # If the log directory doesn't exist, create it.
  if [ ! -d "$LogDir" ]; then
    mkdir -p "$LogDir"
  fi

  # Prepare log file name:
  # - Remove spaces from the log name.
  # - Construct a name using the current date, a base name, and the sanitized log name.
  sanitized_log_name=$(echo "$log_name" | tr -d ' ')
  LOG_FILE="${LogDir}/$(date +'%Y-%m-%d_%H.%M.%S')-${LogBase}-${sanitized_log_name}.log"
  
  # Create an empty log file.
  touch "$LOG_FILE"

  # Redirect standard output and standard error to the log file. 
  # The output will still be shown in the terminal because of `tee -a`.
  exec > >(tee -a "$LOG_FILE") 2>&1

  # Check if the log file was created successfully.
  if [ $? -eq 0 ]; then
    # If successful, log a debug message.
    write_log $DEBUG "Log file $LOG_FILE has been created in $LogDir"
  else
    # If unsuccessful, log an error message.
    write_log $ERROR "Failed to create log file $LOG_FILE in $LogDir"
  fi
}


#############################################################################
# Function name: check_errors_and_notify
# Purpose: Inspects the provided log file for error messages and sends a notification if any are found.
# Parameters:
#   1) LOG_FILE: Path to the log file that needs to be inspected.
#
# Usage: 
#   check_errors_and_notify "/path/to/log/file.log"
#
# Note: The function relies on two external functions, `write_log` for logging and `send_notification` for notifying about errors.

check_errors_and_notify() {
  # Retrieve the path of the log file from the first argument.
  local LOG_FILE=$1

  # Check the provided log file for any lines containing the string "ERROR".
  if grep -q "ERROR" "$LOG_FILE"; then
    
    # Get the last error message from the log file.
    last_error=$(grep "ERROR" "$LOG_FILE" | tail -n 1)
    errormsg=$(echo -e "Last error message:\n $last_error")
    
    # Log the last error message.
    write_log $ERROR "$errormsg"
    
    # Send a notification with details about the error.
    send_notification "Error detected in CopyPics" "urgent" "error,script" "$errormsg"
  fi
}

#############################################################################
# Function name: Error_Exit
# Purpose: Provides a structured exit during an error condition. Performs cleanup and notifications.
# No parameters.
# 
# Usage: 
#   Error_Exit
#
# Note: 
# - Relies on the Rm_Pid function to remove a PID file, the purpose of which might be to indicate that the script is currently running.
# - Uses the write_log function for logging.
# - Uses the check_errors_and_notify function to notify about errors.

Error_Exit() {
  # Remove the PID (Process ID) file.
  # This is likely used to prevent multiple instances of the script from running simultaneously.
  Rm_Pid

  # Log that the PID file was successfully removed.
  write_log $ERROR "Pid File Removed"

  # Check for errors in the log file and send notifications if any errors are detected.
  check_errors_and_notify "$LOG_FILE"

  # Terminate the script, returning an exit code of 1 to indicate an error.
  exit 1
}

#############################################################################
# Function name: Force_Exit
# Purpose: Checks for the existence of a specific file (likely a PID file). If the file does not exist, forcibly terminates the script.
# No parameters.
# 
# Usage: 
#   Force_Exit
#
# Note: 
# - The intended use of the PID file is not fully clear without broader context. Typically, PID files are used to store the process ID of a running instance to prevent multiple simultaneous runs.

Force_Exit() {
  # Check if the PID file does not exist.
  if [[ ! -f "$PID" ]]; then
    # If the PID file doesn't exist, log a "Force Exit" message.
    write_log $ERROR "Force Exit"
    
    # Terminate the script with an exit code of 1, indicating an error.
    exit 1
  fi
}

#############################################################################
# Function: Make_Pid
# Purpose: Check if a PID file exists at a specified location. If it does exist, logs a message 
#          and exits the script. Otherwise, it creates the PID file.
#
# Globals:
#   - PID: The path to the PID file. This variable must be set before calling the function.
#   - write_log: A logging function. This must be defined elsewhere in the script.
#
# Usage:
#   Set the PID variable to the desired path of the PID file and call the Make_Pid function.
#   e.g., PID="/path/to/pidfile.pid"; Make_Pid

Make_Pid() {
  # Check if the PID file exists
  if [[ -e $PID ]]; then
    # If it exists, log an error and exit the script
    write_log $ERROR "PID file $PID already exists. Exiting script."
    exit 1
  fi
  
  # If the PID file doesn't exist, create it
  touch $PID
  write_log $DEBUG "$PID has been created."
}


#############################################################################
# Function name: Rm_Pid
# Purpose: Removes a file from a specified location. This is likely a file that the script creates when it starts to indicate that it's running (a PID file). By removing this file, the script indicates that it is no longer running.
# No parameters.
# 
# Usage: 
#   Rm_Pid
#
# Note: 
# - The `$PID` variable, based on its name, suggests it represents a Process ID file. Such files are used to ensure only a single instance of a script or process is running at a given time.

Rm_Pid() {
  # Remove the file at the location specified by the $PID variable.
  rm -f ${PID}
  write_log $DEBUG "$PID has been removed."
}

#############################################################################
# Function name: perform_file_search
# Purpose: Search for files with specified extensions in a provided directory and its subdirectories, excluding specified directories.
# Parameters:
# - The root directory to begin the search from.
# - An array of directories to exclude from the search.
# - A variable-length list of file extensions to search for.
# - The path to a file where the search results will be saved.

perform_file_search() {
  # Extract the function arguments
  #echo "All arguments: $@"
  local root_dir="$1"
  local directories_arg="$2"
  local extensions_arg="$3"
  local FileList="$4"

  # Access the array values using indirect references
  local directories=("${!directories_arg}")
  local extensions=("${!extensions_arg}")

  # Construct the part of the find command that specifies directories to exclude
  local find_extensions=""
  for extension in "${extensions[@]}"; do
      find_extensions+="-name '*.$extension' -o "
  done

  # Remove the trailing '-o '
  find_extensions="${find_extensions%-o }"

  # Add each directory to exclude to the find command
  for exclude_dir in "${directories[@]}"; do
      excluded_dirs+=" -path '$exclude_dir' -o"
  done

  # Remove the trailing '-o'
  if [ -n "$excluded_dirs" ]; then
      excluded_dirs="${excluded_dirs% -o} -prune -o"
  fi
  
  # Start constructing the find command
  local find_command="find '$root_dir' $excluded_dirs"

  find_command+=" \( -type f $find_extensions \) -print"

  # Print the constructed command (for debugging)
  # write_log $DEBUG "Executing command: $find_command"
  
  # Execute the constructed find command and save the output to the specified file
  eval "$find_command" > "$FileList"

  # Check if the find command was successful
  if [ $? -ne 0 ]; then
    write_log $ERROR  "Error: The find command failed."
    return 1
  fi

  # If everything went well
  write_log $DEBUG "$FileList was successfully created"
  return 0
}




# Example usage:
# perform_file_search "/path/to/search/root" Excluded_Directories "${Allowed_Ext[@]}" "$FileList"


#############################################################################
# The filter_file_list function processes an input file by filtering out lines that:
# 1. Match the first column of a comma-separated database file, or
# 2. Contain the substring '@eaDir'.
# After filtering, the function overwrites the input file with the cleaned content.
#
# Parameters:
# $1: Path to the input file to be filtered
# $2: Path to a temporary file used to store filtered content (this will overwrite the input file at the end)
# $3: Path to the database file with comma-separated values
filter_file_list() {
    # Assign function parameters to named local variables for clarity
    local input_file="$1"
    local temp_file="$2"
    local db_file="$3"

    # Create (or reset if it already exists) the temp_file
    touch "$temp_file"

    # Process each line in the input_file
    while read -r line; do
        # Check if the current line matches the start (up to the comma) of any line in the db_file
        if grep -q "^$line," "$db_file"; then
            # (Optional) Uncomment the next line if you want to log occurrences of lines found in the DB file
            # echo "$line was removed from $input_file" | write_log
            continue  # Skip to the next iteration of the loop (i.e., don't process this line further)
        # Check if the current line contains the substring '@eaDir'
        elif [[ $line == *"@eaDir"* ]]; then
            continue  # Skip lines containing '@eaDir'
        else
            # If the line doesn't match any of the previous conditions, append it to the temp file
            echo "$line" >> "$temp_file"
            #write_log $DEBUG "$line moved to Tempfile!"
        fi
    done < "$input_file"  # Redirect the content of input_file into the while loop for reading

    # Replace the original input_file with the filtered contents from temp_file
    mv "$temp_file" "$input_file"
}

# Example usage:
# filter_file_list "/path/to/input_file" "/path/to/temp_file" "/path/to/db_file"

#############################################################################
# Function: create_temp_config
# Purpose: This function creates an empty temporary configuration file at a specified location.
#
# Parameters:
#   - $1 (required): The path and filename where the temporary configuration file should be created.
#
# Returns:
#   - Path of the created configuration file.
#   - Error message and returns 1 if the path and filename are not provided.
#
# Usage:
#   To create a configuration file named "temp_config.cfg" in the directory "/path/to/configs":
#   create_temp_config "/path/to/configs/temp_config.cfg"
#   This will create an empty file at the specified location.
#
# Note: The function will echo the path of the configuration file, so you can capture this value 
#       in a variable if needed, e.g., config_path=$(create_temp_config "/path/to/configs/temp_config.cfg")

create_temp_config() {
    # Check if the user provided a path and filename
    if [ -z "$1" ]; then
        # If not provided, print an error message and return an error code
        echo "Error: Please specify a path and filename for the temp config."
        return 1
    fi

    # Define the path to the configuration file using the provided argument
    local temp_config="$1"

    # Create an empty file at the specified location
    touch "$temp_config"

    # Print the path of the configuration file, allowing the caller to capture or use the path if needed
    echo "$temp_config"
}



#############################################################################
# Function: add_config_item
# Purpose: This function writes a specified variable and its value to a given configuration file 
#          in the format "export VARIABLE_NAME='VARIABLE_VALUE'". The function assumes the variable 
#          exists in the calling context.
#
# Parameters:
#   - config_file: Path to the configuration file where the variable and its value should be added.
#   - var_name: Name of the variable to be added to the config file.
#
# Returns:
#   - 0: If the variable was added successfully to the config file.
#   - 1: If the variable was not set or empty.
#
# Usage:
#   To add a variable named "LOG_FILE" and its value to a config file at "/path/to/config":
#   LOG_FILE="/path/to/log"
#   add_config_item "/path/to/config" "LOG_FILE"
#
#   This will add a line "export LOG_FILE='/path/to/log'" to the file "/path/to/config".

add_config_item() {
    # Get the file path and variable name from the function arguments
    local config_file="$1"
    local var_name="$2"

    # Use indirect referencing to fetch the value of the given variable
    # This feature allows you to access a variable's value using another variable's content as its name
    local var_value="${!var_name}"

    # Check if the variable exists and has a value
    if [[ -z "$var_value" ]]; then
        # If the variable doesn't have a value, print an error message
        echo "Error: Variable $var_name is not set or empty."
        return 1
    fi

    # Write the variable definition to the configuration file
    # This will append a line in the format "export VARIABLE_NAME='VARIABLE_VALUE'" to the specified file
    echo "export $var_name='$var_value'" >> "$config_file"
}


#############################################################################
# Function: check_and_create_file
# Purpose: This function checks if a specified file exists at a given path. 
#          If the file does not exist, the function creates it.
# Parameters:
#   - file_path: The full path to the file that needs to be checked/created.
#
# Returns:
#   - 0: If the file already exists or has been successfully created.
#   - 1: If there was an error in creating the file.
#
# Usage: 
#   To check and create a file, call the function followed by the file path:
#   check_and_create_file "/path/to/your/file.txt"
#
#   The function will print one of the following messages:
#   1) "File '/path/to/your/file.txt' has been created." (If the file was created successfully)
#   2) "Error: Failed to create file '/path/to/your/file.txt'." (If there was an error in file creation)
#   3) "File '/path/to/your/file.txt' already exists." (If the file already exists)

check_and_create_file() {
    local file_path="$1"  # Retrieve the file path from the function's argument
    
    # Check if the file already exists
    if [[ ! -f "$file_path" ]]; then
        # If it doesn't exist, use 'touch' command to create it
        touch "$file_path"
        
        # Check the exit status of the 'touch' command to determine if file creation was successful
        if [[ $? -eq 0 ]]; then
            # Print a success message if the file was created without issues
            write_log $DEBUG "File '$file_path' has been created."
        else
            # Print an error message if there was an issue in file creation
            write_log $ERROR "Error: Failed to create file '$file_path'."
            return 1  # Return an error code
        fi
    else
        # If the file already exists, inform the user
        write_log $DEBUG "File '$file_path' already exists."
    fi

    # If all went well, return a success code
    return 0
}


#############################################################################
# Function to extract exif data for both dateTimeOriginal and CreateDate
extract_exif_data() {
    local file="$1"
    perl $ExifDir/exiftool -m -d '%s,%Y%m%d_%H%M%S' -p '$dateTimeOriginal,$CreateDate' "$file"
}












#############################################################################
parse_exif_data_and_log() {
    local file="$1"

    # Parse the result into the four variables
    local result=$(extract_exif_data "$file")
    
    local NextFileDateTimeOrigional
    local NextFileDateTimeOrigionalReadable
    local NextFileCreateDate
    local NextFileCreateDateReadable

    if [ -z "$result" ]; then
        NextFileDateTimeOrigional=""
        NextFileDateTimeOrigionalReadable=""
        NextFileCreateDate=""
        NextFileCreateDateReadable=""

        write_log $DEBUG "EXIFTOOL could not give CreateDate or dateTimeOriginal information."
    else
        IFS=',' read -ra values <<< "$result"

        NextFileDateTimeOrigional="${values[0]}"
        NextFileDateTimeOrigionalReadable="${values[1]}"
        NextFileCreateDate="${values[2]}"
        NextFileCreateDateReadable="${values[3]}"
        
        write_log $DEBUG "$NextFile has the following EXIF dateTimeOriginal date: $NextFileDateTimeOrigionalReadable"
        write_log $DEBUG "$NextFile has the following EXIF Createdate date: $NextFileCreateDateReadable"
    fi

    # File modification Date
    local NextFileLinuxModDate=$(date -r "$file" +"%s")
    local NextFileLinuxModDateReadable=$(date -r "$file" +"%Y%m%d_%H%M%S")
    write_log $DEBUG  "$NextFile has the following Linux modification date: $NextFileLinuxModDateReadable"


    local Keywords=$(perl $ExifDir/exiftool -s -s -s -Keywords "$SearchDir"/"$NextFile")
    local keyword_size=${#Keywords}

    if [[ $keyword_size -gt 0 ]]; then
      #write_log $DEBUG "$NextFile had a Keyword Size of $keyword_size characters"
      write_log $DEBUG "$NextFile has the following Keywords: $Keywords"
    fi



}

# Example usage:
# parse_exif_data_and_log "/path/to/search/filename.ext"

#############################################################################
copy_file(){
  if [[ -e "$SearchDir"/"$NextFile2" ]]; then
        write_log $DEBUG "File $NextFile2 already exists."
    else
        write_log $DEBUG "$(perl $ExifDir/exiftool -o -P "-FileName=$NextFile2" "$SearchDir"/"$NextFile")"

        # Check the exit status of exiftool
        if [[ $? -ne 0 ]]; then
            write_log $ERROR "Failed to execute exiftool on "$SearchDir"/"$NextFile"" >&2
            # handle error, e.g., exit or continue with alternative action
        else
            # Check if the new file exists
            if [[ ! -f "$SearchDir"/"$NextFile2" ]]; then
                write_log $ERROR "Expected file $NextFile2 was not created" >&2

                # Call the function
                title="Error in CopyPics.sh"
                priority="High"
                tags="Alert"
                message="Expected file $NextFile2 was not created"

                send_notification "$title" "$priority" "$tags" "$message"
                # handle error, e.g., exit or continue with alternative action
                continue
            else
                write_log $DEBUG "Copy of $NextFile was created and named $NextFile2"
            fi
        fi
    fi

}

#############################################################################
#############################################################################
