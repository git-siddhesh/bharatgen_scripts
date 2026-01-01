#!/bin/bash

set -euo pipefail
shopt -s dotglob nullglob

CONFIG_FILE=${1:-config.json}

command -v jq >/dev/null || { echo "jq required"; exit 1; }
command -v aws >/dev/null || { echo "aws cli required"; exit 1; }


########################################
# DEFAULTS
########################################
DEFAULT_REGION="ap-south-1"
DEFAULT_BUCKET_ROOT=""
DEFAULT_BUCKET_ROOT_EXISTING=false
DEFAULT_USERNAME="ADMIN"

DEFAULT_BASE_PATHS=("/projects/data" "/nfs" "/weka" "/home")
# check the base paths one by one and if the path exists then set it to the default base path
for path in "${DEFAULT_BASE_PATHS[@]}"; do
  if [[ -d "$path" ]]; then
    DEFAULT_BASE_PATH="$path"
    break
  fi
done
echo "Default base path: $DEFAULT_BASE_PATH"

DEFAULT_MAX_JOBS=32
DEFAULT_PROGRESS_FREQ=15
DEFAULT_CP_MODE=false
DEFAULT_CHECKSUM=true
DEFAULT_COMPUTE_SIZE=true
DEFAULT_DU_DEPTH=1


########################################
# AWS CREDS (HARDCODED – AS REQUESTED)
########################################
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
AWS_REGION=$(jq -r ".aws.region // \"$DEFAULT_REGION\"" "$CONFIG_FILE")
export AWS_REGION


########################################
# S3 CONFIG
########################################
BUCKET=$(jq -r '.s3.bucket' "$CONFIG_FILE")
BUCKET_ROOT=$(jq -r ".s3.source_server // \"$DEFAULT_BUCKET_ROOT\"" "$CONFIG_FILE")
# if Bucket root == 'yotta' then set it to 'v1'
if [[ "$BUCKET_ROOT" == "yotta" ]]; then
  BUCKET_ROOT="v1"
fi
BUCKET_ROOT_EXISTING=$(jq -r ".s3.bucket_root_existing // $DEFAULT_BUCKET_ROOT_EXISTING" "$CONFIG_FILE")
USERNAME=$(jq -r ".s3.username // \"$DEFAULT_USERNAME\"" "$CONFIG_FILE")


########################################
# TRANSFER CONFIG
########################################
BASE_PATH=$(jq -r ".transfer.ommitted_data_path // \"$DEFAULT_BASE_PATH\"" "$CONFIG_FILE")
MAX_JOBS=$(jq -r ".transfer.max_parallel_jobs // $DEFAULT_MAX_JOBS" "$CONFIG_FILE")
PROGRESS_FREQ=$(jq -r ".transfer.progress_frequency // $DEFAULT_PROGRESS_FREQ" "$CONFIG_FILE")
IS_CP_MODE=$(jq -r ".transfer.is_cp_recursive_only_transfer_mode // $DEFAULT_CP_MODE" "$CONFIG_FILE")
CHECKSUM_ENABLED=$(jq -r ".transfer.checksum_enabled // $DEFAULT_CHECKSUM" "$CONFIG_FILE")
COMPUTE_SIZE=$(jq -r ".transfer.compute_size // $DEFAULT_COMPUTE_SIZE" "$CONFIG_FILE")
DU_DEPTH=$(jq -r ".transfer.du_depth // $DEFAULT_DU_DEPTH" "$CONFIG_FILE")

mapfile -t SOURCES < <(jq -r '.transfer.sources[]?' "$CONFIG_FILE")


########################################
# LOGGING
########################################
LOG_NAME="$USERNAME"

LOG_DIR="/app/logs/${LOG_NAME}"
RESULT_DIR="/app/results/${LOG_NAME}"
mkdir -p "$LOG_DIR" "$RESULT_DIR"

STATUS_LOG="${LOG_DIR}/status.log"
DU_LOG="${LOG_DIR}/du.log"
SUMMARY_LOG="${LOG_DIR}/summary.log"
FAILED_LOG="${LOG_DIR}/failed.log"
SUMMARY_LOCK="${LOG_DIR}/.summary.lock"

RUN_HEADER="===== NEW RUN: $(date '+%F %T') ====="

echo "$RUN_HEADER" | tee -a "$STATUS_LOG"
echo "$RUN_HEADER" | tee -a "$SUMMARY_LOG"
echo "$RUN_HEADER" | tee -a "$FAILED_LOG"
echo "SRC | SIZE_GB | START | END | DURATION_SEC | SPEED_GB_MIN" | tee -a "$SUMMARY_LOG"


########################################
# VALIDATION
########################################
if [[ -z "$BUCKET" ]]; then
  echo "ERROR: s3.bucket is required" | tee -a "$FAILED_LOG"
  exit 1
fi

if ((${#SOURCES[@]} == 0)); then
  echo "ERROR: transfer.sources must contain at least one path" | tee -a "$FAILED_LOG"
  exit 1
fi


########################################
# S3 ROOT
########################################
if [[ -z "$BUCKET_ROOT" ]]; then
  S3_ROOT="s3://${BUCKET}/${USERNAME}"
else
  S3_ROOT="s3://${BUCKET}/${USERNAME}/${BUCKET_ROOT}"

  if [[ "$BUCKET_ROOT_EXISTING" == "true" ]]; then
    aws s3 ls "$S3_ROOT" >/dev/null 2>&1 || {
      echo "S3 path does not exist: $S3_ROOT" | tee -a "$FAILED_LOG"
      exit 1
    }
  fi
fi

########################################
# HELPERS
########################################
wait_for_slot() {
  while (( $(jobs -r | wc -l) >= MAX_JOBS )); do sleep 1; done
  echo "✅ Slot available. Starting new transfer job..." | tee -a "$STATUS_LOG"
}

run_du_async() {
  SRC="$1"
  DU_FILE="$2"

  if [[ "$COMPUTE_SIZE" == "true" ]]; then
    (
      du -sb "$SRC" | awk '{print $1}' > "$DU_FILE" 2>/dev/null || echo 0 > "$DU_FILE"
    ) &
    echo $!
  else
    echo ""
  fi
}


checksum_flag() {
  if [[ "$CHECKSUM_ENABLED" == "true" ]]; then
    echo "--checksum-algorithm CRC32C"
  else
    echo ""
  fi
}


# ----------------------------
# Log everything to terminal and log file
echo "================================================" | tee -a "$STATUS_LOG"
echo "Bucket: $BUCKET" | tee -a "$STATUS_LOG"
echo "Bucket root: $BUCKET_ROOT" | tee -a "$STATUS_LOG"
echo "Bucket root existing: $BUCKET_ROOT_EXISTING" | tee -a "$STATUS_LOG"
echo "Username: $USERNAME" | tee -a "$STATUS_LOG"
echo "Base path: $BASE_PATH" | tee -a "$STATUS_LOG"
echo "Max jobs: $MAX_JOBS" | tee -a "$STATUS_LOG"
echo "Progress frequency: $PROGRESS_FREQ" | tee -a "$STATUS_LOG"
echo "Is cp mode: $IS_CP_MODE" | tee -a "$STATUS_LOG"
echo "Checksum enabled: $CHECKSUM_ENABLED" | tee -a "$STATUS_LOG"
echo "Compute size: $COMPUTE_SIZE" | tee -a "$STATUS_LOG"
echo "Du depth: $DU_DEPTH" | tee -a "$STATUS_LOG"
echo "Sources: ${SOURCES[*]}" | tee -a "$STATUS_LOG"
echo "Log name: $LOG_NAME" | tee -a "$STATUS_LOG"
echo "Log dir: $LOG_DIR" | tee -a "$STATUS_LOG"
echo "Result dir: $RESULT_DIR" | tee -a "$STATUS_LOG"
echo "Status log: $STATUS_LOG" | tee -a "$STATUS_LOG"
echo "Summary log: $SUMMARY_LOG" | tee -a "$STATUS_LOG"
echo "Failed log: $FAILED_LOG" | tee -a "$STATUS_LOG"
echo "===== NEW RUN: $(date '+%F %T') =====" | tee -a "$STATUS_LOG"
echo "================================================" | tee -a "$STATUS_LOG"

########################################
# TRANSFER FUNCTION
########################################
transfer_one() {
  set +e
  set +u
  set +o pipefail

  SRC="$1"
  REL="${SRC#$BASE_PATH/}"
  DST="${S3_ROOT}/${REL}"

  SAFE_NAME=$(echo "$REL" | tr '/' '_')
  DU_FILE="${RESULT_DIR}/${LOG_NAME}_${SAFE_NAME}.du"

  START_TS=$(date +%s)
  START_H=$(date "+%F %T")
  DU_START_TS=$START_TS

  DU_PID=$(run_du_async "$SRC" "$DU_FILE")
  CHECKSUM_ARG=$(checksum_flag)

  echo "[START] $(date '+%F %T') | $REL | $SRC → $DST" | tee -a "$STATUS_LOG"
  CMD=(aws s3)

  if [[ -f "$SRC" ]]; then
    CMD+=(cp "$SRC" "$DST")
  else
    if [[ "$IS_CP_MODE" == "true" ]]; then
      CMD+=(cp "$SRC" "$DST" --recursive)
    else
      CMD+=(sync "$SRC" "$DST")
    fi
  fi

  CMD+=(--progress-frequency "$PROGRESS_FREQ" --no-follow-symlinks --ignore-glacier-warnings --cli-read-timeout 600 --cli-connect-timeout 300)

  if [[ "$CHECKSUM_ENABLED" == "true" ]]; then
    CMD+=(--checksum-algorithm CRC32C)
  fi

  echo "CMD: ${CMD[*]} $(date '+%F %T')" | tee -a "$STATUS_LOG"

    # 4. Execute the command
  # "${CMD[@]}" expands the array elements exactly as they were defined
  "${CMD[@]}" >> "$STATUS_LOG" 2>&1

  AWS_RC=$?

  echo "[AWS DONE]  $(date '+%F %T') | $REL" | tee -a "$STATUS_LOG"







  TRANSFER_END_TS=$(date +%s)
  END_H=$(date "+%F %T")
  DURATION=$((TRANSFER_END_TS - START_TS))

  if [[ $AWS_RC -ne 0 ]]; then
    echo "[FAIL] | ${CMD[*]} | $(date '+%F %T') | $REL | aws_exit_code=$AWS_RC" | tee -a "$STATUS_LOG"
    echo "[FAIL] | ${CMD[*]} | $(date '+%F %T') | $REL | aws_exit_code=$AWS_RC" | tee -a "$FAILED_LOG"
    return
  fi

  if [[ -n "$DU_PID" ]]; then
    wait "$DU_PID" 2>/dev/null || true
  fi

  if [[ -s "$DU_FILE" ]] && [[ "$(cat "$DU_FILE")" =~ ^[0-9]+$ ]]; then
    SIZE_BYTES=$(cat "$DU_FILE")
  else
    SIZE_BYTES=0
  fi


  DU_END_TS=$(date +%s)
  DU_TIME=$((DU_END_TS - DU_START_TS))
  OVERLAP=$(( TRANSFER_END_TS > DU_END_TS ? DU_TIME : TRANSFER_END_TS - DU_START_TS ))

  if [[ "$SIZE_BYTES" -gt 0 ]]; then
    SIZE_GB=$(awk -v b="$SIZE_BYTES" 'BEGIN {printf "%.4f", b/1024/1024/1024}')
  else
    SIZE_GB=""
  fi



  SPEED="N/A"
  if [[ "$DURATION" -gt 0 && "$SIZE_BYTES" -gt 0 ]]; then
    SPEED=$(awk -v g="$SIZE_GB" -v d="$DURATION" 'BEGIN {printf "%.4f", g/(d/60)}')
  fi


  echo "METRICS | $REL | TRANSFER=${DURATION}s DU=${DU_TIME}s OVERLAP=${OVERLAP}s" | tee -a "$STATUS_LOG"
  {
    flock -x 200
    echo "$REL | $SIZE_GB | $START_H | $END_H | $DURATION | $SPEED"
  } 200>"$SUMMARY_LOCK" >> "$SUMMARY_LOG"

  echo "[DONE] $(date '+%F %T') | $REL | ${SPEED}GB/min" | tee -a "$STATUS_LOG"
}



########################################
# MAIN
########################################
for SRC in "${SOURCES[@]}"; do
  if [[ -f "$SRC" ]]; then
    wait_for_slot
    transfer_one "$SRC" &
  else
    for ENTRY in "$SRC"/*; do
      wait_for_slot
      transfer_one "$ENTRY" &
    done
  fi
done

wait

echo "All transfers complete" | tee -a "$STATUS_LOG"
chmod -R 777 "$LOG_DIR" "$RESULT_DIR"
echo "✅ Giving the read/write/delete permissions to all completed" | tee -a "$STATUS_LOG"



