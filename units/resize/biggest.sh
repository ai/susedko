#!/bin/bash

OUTPUT_DIR="/var/mnt/vault/ai/New"

find $OUTPUT_DIR -type f -exec du -h {} + | sort -hr | head -n 35
