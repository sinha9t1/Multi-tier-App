#!/bin/bash

#*****************************************
# Script Name: composeBuildUP.sh 
# Purpose    : Capture STDOUT and STERR from implicit command ==> docker compose build up -d 
# Usage      : (Custom replacement of docker compose build -d)
#*****************************************
#
## Variables ##
LOG_DIR="/home/devops/3-tier-app/build-logs"
DATE="$(date +%y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/docker_build_$DATE.log"

#Check if the directory exists
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

#Print Start message
echo "Starting docker compose build - $DATE" | tee -a $LOG_FILE
echo "Log File: $LOG_FILE" | tee -a $LOG_FILE

#Run the command to capture output to log file and display on terminal
docker compose up --build -d 2>&1 | tee -a $LOG_FILE

#Check the exit status of the previous command.
if [ $? -eq 0 ]; then
    echo "Build and startup completed successfully... - $DATE." | tee -a $LOG_FILE	
else
    echo "Build Failed!! Check log --> $LOG_FILE with $DATE" | tee -a $LOG_FILE
    exit 1
fi    
  	
 
