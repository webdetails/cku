#!/bin/bash
# The contents of this file are subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.


show_help() {
  echo "Sintax: $0 -parameter=value ..."
  echo "General parameters:"
  echo "  -h (help)"
  echo "  -r=file (read parameters from file)"
  echo "Mandatory parameters:"
  echo "  -j=job name (used for log/lock filenames)"
  echo "  -c=command to run"
  echo "Non-mandatory parameters:"
  echo "  -l=job long name (defaults to job name)"
  echo "  -w=seconds (wait for another job instance with same job name to finish."
  echo "     default is 0, which disables locking)"
 }

# parse options:
while getopts "j:c:l:w:r:h" opt; do
  case $opt in
    j) JOB_NAME="$OPTARG" ;;
    c) CMD="$OPTARG" ;;
    l) JOB_LONG_NAME="$OPTARG" ;;
    w) LOCK_TIMEOUT="$OPTARG" ;;
    r) SETTINGS_FILE="$OPTARG" ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      show_help
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      show_help
      exit 1
      ;;
  esac
done

# read from settings file if provided on command line:
if [ "$SETTINGS_FILE" != "" ]; then
  if [ ! -r "$SETTINGS_FILE" ]; then 
    echo "ERROR: The options file '$SETTINGS_FILE' cannot be read."
    exit 1
  fi
  source "$SETTINGS_FILE"
fi

# check mandatory options:
if [ "$JOB_NAME" == "" -o "$CMD" == "" ]; then
  echo "Error: missing arguments."
  show_help
  exit 1
fi
 
# defaults:
JOB_LONG_NAME=${JOB_LONG_NAME:-$JOB_NAME}
LOG_DIR=${LOG_DIR:-"/tmp"}
LOCK_DIR=${LOCK_DIR:-"/tmp"}
LOCK_TIMEOUT=${LOCK_TIMEOUT:-"0"}
TIMESTAMP=`date "+%Y%m%d_%H%M%S"`
LOG_FILEPATH=${LOG_FILEPATH:-"${LOG_DIR}/${JOB_NAME}_${TIMESTAMP}.log"}
LOCK_FILEPATH=${LOCK_FILEPATH:-"${LOG_DIR}/${JOB_NAME}.lock"}
OUTPUT_SIZE=${OUTPUT_SIZE:-50}

# open $LOCK_FILEPATH for locking as file descriptor = 200 :
exec 200>"$LOCK_FILEPATH";

# handle locking:
if [ "$LOCK_TIMEOUT" -gt "0" ] ; then
  # check if $LOCK_FILEPATH is already locked:
  if ! flock -n -x 200 ; then
    echo "Warning: The job ${JOB_LONG_NAME} is already running."
    echo "Warning: waiting for $LOCK_TIMEOUT seconds."
    # check again but wait for $LOCK_TIMEOUT seconds for lock release:
    if ! flock -w $LOCK_TIMEOUT -x 200; then
      echo "Error: the job was still running after $LOCK_TIMEOUT seconds. Quiting!"
      exit 1
    fi
  fi
fi

# execute: 
$CMD > "$LOG_FILEPATH" 2>&1 
RETVAL=$?
if [ $RETVAL = 0 ]; then
  echo "Job $JOB_LONG_NAME succeeded."
  echo "Complete job log is at: $LOG_FILEPATH"
else
  echo "Error: Job $JOB_LONG_NAME failed, exit value was '$RETVAL'"
  echo "Info: Complete job log is at: $LOG_FILEPATH"
  echo "Info: last $OUTPUT_SIZE lines:"
  tail -$OUTPUT_SIZE "$LOG_FILEPATH"
fi
rm -f "$LOCK_FILEPATH"
exit $RETVAL

