#!/bin/bash

TASKS_DIR="/var/mnt/vault/ai/Resize"
OUTPUT_DIR="/var/mnt/vault/ai/New"

if pgrep -u "$(whoami)" ffmpeg > /dev/null 2>&1; then
  echo "ffmpeg is already running under this user. Exiting script."
  exit 0
fi

FIRST_TASK=$(find "$TASKS_DIR" -type f -print | head -n 1)

echo $FIRST_TASK

if [ -z "$FIRST_TASK" ]; then
  echo "No files found in work dir."
  exit 0
fi

clean_filename() {
  local filename=$(basename "$1")
  filename=${filename//-1080p/}
  filename=${filename//.1080p/}
  filename=${filename//_1080p/}
  filename=${filename//1080p/}
  filename=${filename//-1080/}
  filename=${filename//.1080/}
  filename=${filename//_1080/}
  filename=${filename//1080/}
  filename=${filename//_5568x3132/}
  filename=${filename//5568x3132/}
  filename=${filename//_7680x4320/}
  filename=${filename//7680x4320/}
  echo "$filename"
}

CLEANED_NAME=$(clean_filename "$FIRST_TASK")

ffmpeg -y -i "$FIRST_TASK" -vf "scale=-1:720" "$OUTPUT_DIR/$CLEANED_NAME"
rm "$FIRST_TASK"
