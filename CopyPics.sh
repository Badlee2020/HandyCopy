#!/bin/bash

# move handy photos (from DCIM) to final folder (/Media/Pictures/%YYYY/%YYYY_MM_DD) 



# /volume3/scripts/Development/HandyCleanup/HandyCleanup.sh CopyPics -i /volume3/scripts/Development/HandyCleanup/InputDir -s /volume3/scripts/Development/HandyCleanup/SortDir -f /volume3/scripts/Development/HandyCleanup/FinalDir

# PhonePicsCopy -i /volume3/homes/JJ/Photos/MobileBackup -s /volume3/scripts/Picture_Cleanup/Sort -d /volume3/scripts/Picture_Cleanup/OutDir
# -i Input Directory
# -s sort directory
# -d destination directory

# Set up output redirection to log file
#exec > >(tee -a "$LOG_FILE") 2>&1

# Get the directory of the script itself
BaseDir=$(dirname "$(realpath "$0")")

# -----------------
# Variables Configuration
# -----------------

# Load variables file
source $BaseDir/config.cfg

# Load functions
source $BaseDir/Functions.sh

source $BaseDir/tmp.cfg




# -----------------
# Script Functions
# -----------------
function handle_whatsapp_file() {
  local file="$1"
  local file_base_name=$(basename "$file")
  
  write_log $DEBUG "WhatsApp match: $NextFile"

  # Get Time from DateTimeOriginal
  local WAFileTimeOrigionalReadable=$(perl $ExifDir/exiftool -d '%H:%M:%S' -p '$FileModifyDate' "$file")
  
  local FileNameTimestamp=$(echo "$file" | grep -oP '\d{8}')
	
  # Date formatting
  local FileNameDateNew="${FileNameTimestamp:0:4}:${FileNameTimestamp:4:2}:${FileNameTimestamp:6:2}"

  local FileNameDateYear="${FileNameTimestamp:0:4}"
  local FileNameDateMonth="${FileNameTimestamp:4:2}"
  local FileNameDateDay="${FileNameTimestamp:6:2}"


  # Create Timestamp
  local NewWhatsAppDateTime="$FileNameDateNew $WAFileTimeOrigionalReadable"

  # Logging for testing
  write_log $DEBUG "$file_base_name will get the following Timestamp: $NewWhatsAppDateTime"

  #Use Exiftool to give it a new dateTimeOriginal Timestamp
  write_log $DEBUG "$(perl $ExifDir/exiftool -P -overwrite_original "-alldates=${NewWhatsAppDateTime}" "$SearchDir/$NextFile2")"

  write_log $DEBUG "All Dates for $NextFile2 have been Updated to $NewWhatsAppDateTime"

  write_log $DEBUG "$(perl $ExifDir/exiftool -P -overwrite_original "-filemodifydate<datetimeoriginal" "-filecreatedate<datetimeoriginal" "$SearchDir/$NextFile2")"
  write_log $DEBUG "FileModifyDate and FileCreateDate for $NextFile2 have been updated to $NewWhatsAppDateTime"

  if [[ -e "$SortDestinationPathWhatsApp/$NextFile2" ]]; then
      write_log $DEBUG "File $SearchDir/$NextFile2 already exists."
      #### check date and tags
  else

    # Handle file based on Keywords
    if [[ "$Keywords" =~ Sort ]] || [[ $keyword_size -lt 1 ]]; then

    
      # Execute exiftool and capture its output
      EXIF_OUTPUT=$(perl $ExifDir/exiftool -P '-Keywords+=Sort' -overwrite_original -d "$SortDestinationPathWhatsApp"/%Y/%Y_%m_%d "-directory<datetimeoriginal" "$SearchDir"/"$NextFile2" 2>&1)

      # Check the exit status of exiftool
      if [[ $? -eq 0 ]]; then
          write_log $DEBUG "$EXIF_OUTPUT"
          write_log $DEBUG "Moving $NextFile2 to ${SortDestinationPath} added 'Sort' as keyword"
      else
          write_log $ERROR "Exiftool encountered an error: $EXIF_OUTPUT"
      fi

      # recreate Should file Path/name at end location
      ShouldDestDir=$SortDestinationPathWhatsApp/$FileNameDateYear/$FileNameDateYear"_"$FileNameDateMonth"_"$FileNameDateDay 
      ShouldFile=$ShouldDestDir/$NextFile2

    elif [[ $keyword_size -gt 0 ]]; then

      # Execute exiftool and capture its output
      EXIF_OUTPUT=$(perl $ExifDir/exiftool -P '-Keywords-=Sort' '-Keywords+=WhatsApp' -overwrite_original -d "$DestinationPath"/%Y/%Y_%m_%d "-directory<dateTimeOriginal" "$SearchDir"/"$NextFile2" 2>&1)

      # Check the exit status of exiftool
      if [[ $? -eq 0 ]]; then
          write_log $DEBUG "$EXIF_OUTPUT"
          write_log $DEBUG "moving $NextFile2 to  ${DestinationPath}...Adding 'WhatsApp' as keyword"
      else
          write_log $ERROR "Exiftool encountered an error: $EXIF_OUTPUT"
      fi

  
      
      ThisKeyword=$(perl $ExifDir/exiftool -s -s -s -Keywords "$ShouldFile")

      write_log $DEBUG "$NextFile2 has the following keywords ($ThisKeyword)"
      
      # recreate Shoud file Path/name at end location
      ShouldDestDir=$DestinationPath/$FileNameDateYear/$FileNameDateYear"_"$FileNameDateMonth"_"$FileNameDateDay 
      ShouldFile=$ShouldDestDir/$NextFile2
    fi 
  fi
}




# -----------------
# Parse arguments
# -----------------

# Parse command-line arguments
while (( "$#" )); do
  case "$1" in
    -t|--test)
      # If the -t or --test option is provided, set TEST_MODE to true
      TEST_MODE=true
      shift
      ;;
    -i|--inputdir)
      
      if [ -n "$2" ]; then
        InputDir=$2
        shift 2
      else
        echo "Error: --input requires an argument" >&2
        exit 1
      fi
      ;;
    -s|--sortdir)
      
      if [ -n "$2" ]; then
        # Description
        SortDestinationPath=$2
        shift 2
      else
        echo "Error: --dir requires an argument" >&2
        exit 1
      fi
      ;;
    -f|--finaldir)
      
      if [ -n "$2" ]; then
        DestinationPath=$2
        shift 2
      else
        echo "Error: --link requires an argument" >&2
        exit 1
      fi
      ;;
    *) 
      # If an unrecognized option is provided, print an error message and terminate the script
      echo "Error: Invalid parameter $1" >&2
      exit 1
      ;;
  esac
done

# -----------------
# Script starts here
# -----------------

Make_Pid

#write_log $DEBUG "$User called the script."




write_log $DEBUG "******************************************"
write_log $DEBUG "Copy Pictures from Phone Folders" 
write_log $DEBUG "******************************************" 





# If the script is NOT in TEST_MODE
if [[ "$TEST_MODE" == "false" ]]; then
  # get the latest version of exiftool from GitHub
  update_exiftool
  
fi


 

write_log $DEBUG "++++++++++++++++++++++++++++++++++++++++++"

# run Checks
write_log $DEBUG "Running Checks" 

#########  Check if all necessary directories exist
# Check if Working Directory exists or Create it
check_directory_exists_or_create "$WorkingDir" true
# Check if Working/User Directory exists or Create it
check_directory_exists_or_create "$UserDir" true
# Check if Working/User/Function Directory exists or Create it
check_directory_exists_or_create "$FunctionDir" true
# Check if Working/User/Function/Temp Directory exists or Create it
check_directory_exists_or_create "$TempDir" true


# Check if Working/User/DB_Folder Directory exists or Create it
check_directory_exists_or_create "$DBDir" true

# Check if ExifTool Directory Exists
check_directory_exists_or_create "$ExifDir" false

check_and_create_file "$DBFile"

# run Checks
write_log $DEBUG "Checks Completed" 



write_log $DEBUG "++++++++++++++++++++++++++++++++++++++++++"
#Clean up old Log Files		
find $LogDir -type f -name "*$LogDir*" -mtime +100 -delete;
		
#Log
write_log $DEBUG  "Cleaned up old log files" 


write_log $DEBUG "++++++++++++++++++++++++++++++++++++++++++"


# Create list of files to check
perform_file_search "$InputDir" Excluded_Directories[@] Allowed_Ext[@] "$FileList"

# Check the function's return value
if [ $? -ne 0 ]; then
    write_log $ERROR "Error: perform_file_search failed!"
    Exit
fi

# number of lines in $ListList
NumOfFiles=$(wc -l < $FileList)

# Log Number of Files found in $InputDir
write_log $DEBUG "$NumOfFiles files were found in $InputDir"

# Clean up "FileList" Remove entries already in Database
filter_file_list "$FileList" "$FileList_Temp" "$DBFile"

#number of lines in $ListList
NumOfFiles=$(wc -l < $FileList)

# Log number of files not already in DB
write_log $DEBUG "$NumOfFiles files will be processed..."

# Description
SortDestinationPathWhatsApp=$SortDestinationPath/$WhatsAppDir

#loop through files in list
while read NextLine; do

  Force_Exit
  
  # Get $Searchdir (get Full directory from $searchpath)
  SearchDir="$(dirname "${NextLine}")"

  # Get Filename
	NextFile="$(basename "${NextLine}")"

  write_log $DEBUG "++++++++++++++++++++++  $NextFile  ++++++++++++++++++++++"
	write_log $DEBUG  "$NextLine is being Processed......"

	if [[ "$NextLine" != "/"* ]]; then
		write_log $ERROR  "ERROR: Read of $NextLine Failed"
		continue
	fi

  # Description
	((Count=Count+1))
			
	# Print which number x of 100
	write_log $DEBUG "$NextFile is number $Count from $NumOfFiles"

  #get File Name
	NextFileName="${NextFile%.*}" 

	#Get File Extension
	NextFileExt="${NextFile##*.}"
  
  NextFile2=$NextFileName"_"$User"."$NextFileExt
	#write_log $DEBUG "$NextFile will be renamed to $NextFile2"




  if [[ ${Allowed_IMG_Ext} == *"$NextFileExt"* ]]; then
    write_log $DEBUG "$NextFile is an Image"

    parse_exif_data_and_log "$SearchDir"/"$NextFile"

    copy_file
    

    # WhatsApp condition:
    if [[ "$NextFile" =~ -WA0 ]]; then
        
        handle_whatsapp_file "$SearchDir"/"$NextFile"
    
    
    elif [[ $NextFile =~ $regex ]]; then
      
      FileNameTimestamp=""
      #echo "File $NextFile has a timestamp"
      FileNameTimestamp=$(echo "$NextFile" | grep -oP '\d{8}_\d{6}')
                
      #echo "IMG_20211205_125044.jpg" |  grep -Eo '[[:digit:]]{8}_[[:digit:]]{6}'
      write_log $DEBUG "$NextFile has the following file timestamp in its name $FileNameTimestamp"
      
      FormattedFileNameDateTime="${FileNameTimestamp:0:4}:${FileNameTimestamp:4:2}:${FileNameTimestamp:6:2} ${FileNameTimestamp:9:2}:${FileNameTimestamp:11:2}:${FileNameTimestamp:13:2}"
      #write_log $DEBUG "$NextFile has the following formatted timestamp in filename: $FormattedFileNameDateTime"

      continue
    else
      write_log $DEBUG "$NextFile is not a whatsapp file or have a timestamp in name"
      continue
    fi


  elif [[ ${Allowed_Mov_Ext} == *"$NextFileExt"* ]]; then
						
				write_log $DEBUG "$NextFile is a Video"


        continue




  fi

  

  if [[ -f "$ShouldFile" ]]; then
		write_log $DEBUG "$ShouldFile file Exists"

    # Construct the string with NextLine as the first value and Shouldfile as the second
    line_to_append="$NextLine,$Shouldfile"

    # Append the constructed line to the DB file
    echo "$line_to_append" >> "$DBFile"

    last_line=$(tail -n 1 "$DBFile")
    if [ "$last_line" == "$NextLine" ]; then
        write_log $DEBUG "$NextLine _-->_ $ShouldFile added to $DBFile"
    else
        write_log $ERROR "$NextLine was not added to $DBFile"
    fi

	else
							
	  write_log $ERROR "$ShouldFile file does not exist" 
	  rm "$SearchDir/$NextFile2"

    # Call the function
    title="Error in CopyPics.sh"
    priority="High"
    tags="Alert"
    message="$NextFile2 could not be copied to $ShouldFile or added to $DBFile."

    send_notification "$title" "$priority" "$tags" "$message"

							
							
	fi

done < $FileList







check_errors_and_notify "$LOG_FILE"
Rm_Pid
