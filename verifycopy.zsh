#!/bin/zsh

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RESET=$'\033[0m'

echo "=== File Copy Verification by Path, Size, and (Optional) Timestamp ==="
echo -n "Enter path to SOURCE folder: "
read SOURCE

echo -n "Enter path to DESTINATION folder: "
read DEST

echo -n "Do you want to check timestamps as well? (yes/no): "
read CHECK_TIMESTAMP_INPUT

if [[ "$CHECK_TIMESTAMP_INPUT" =~ ^[Yy](es)?$ ]]; then
  CHECK_TIMESTAMP=true
else
  CHECK_TIMESTAMP=false
fi

# Validate input
if [[ ! -d "$SOURCE" ]]; then
  echo "${RED}Error: Source folder does not exist.${RESET}"
  exit 1
fi

if [[ ! -d "$DEST" ]]; then
  echo "${RED}Error: Destination folder does not exist.${RESET}"
  exit 1
fi

TMP_SRC=$(mktemp)
TMP_DST=$(mktemp)

# Set output file path relative to actual script location
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DIFF_FILE="$SCRIPT_DIR/verifycopy_diff_output.txt"
: > "$DIFF_FILE"

# Use timestamp if selected
if $CHECK_TIMESTAMP; then
  echo "${YELLOW}Scanning source with timestamp...${RESET}"
  cd "$SOURCE"
  find . -type f ! -name '._*' -exec stat -f "%N %z %m" {} \; | sort > "$TMP_SRC"

  echo "${YELLOW}Scanning destination with timestamp...${RESET}"
  cd "$DEST"
  find . -type f ! -name '._*' -exec stat -f "%N %z %m" {} \; | sort > "$TMP_DST"
else
  echo "${YELLOW}Scanning source without timestamp...${RESET}"
  cd "$SOURCE"
  find . -type f ! -name '._*' -exec stat -f "%N %z" {} \; | sort > "$TMP_SRC"

  echo "${YELLOW}Scanning destination without timestamp...${RESET}"
  cd "$DEST"
  find . -type f ! -name '._*' -exec stat -f "%N %z" {} \; | sort > "$TMP_DST"
fi

echo "${YELLOW}Comparing files...${RESET}"

# Generate readable diff output
diff --side-by-side --suppress-common-lines "$TMP_SRC" "$TMP_DST" | while IFS= read -r line; do
  if [[ "$line" == *"|"* ]]; then
    echo "CHANGED: $line" >> "$DIFF_FILE"
  elif [[ "$line" == *"<"* ]]; then
    echo "MISSING in DEST: ${line%%<*}" >> "$DIFF_FILE"
  elif [[ "$line" == *">"* ]]; then
    echo "MISSING in SOURCE: ${line##*>}" >> "$DIFF_FILE"
  fi
done

# Cleanup temp files
rm -f "$TMP_SRC" "$TMP_DST"

# Output results
if [[ ! -s "$DIFF_FILE" ]]; then
  echo "${GREEN}Success: All files match by path, size$($CHECK_TIMESTAMP && echo ', and modification time').${RESET}"
  echo "No diff file generated since no mismatches were found."
  rm -f "$DIFF_FILE"
else
  echo "${RED}Mismatch detected!${RESET}"
  echo "${YELLOW}A detailed diff file has been saved at:${RESET} $DIFF_FILE"
  echo ""
  echo "${YELLOW}Quick Summary:${RESET}"
  while IFS= read -r line; do
    if [[ "$line" == CHANGED:* ]]; then
      echo "${RED}$line${RESET}"
    elif [[ "$line" == MISSING\ in\ DEST:* ]]; then
      echo "${RED}$line${RESET}"
    elif [[ "$line" == MISSING\ in\ SOURCE:* ]]; then
      echo "${YELLOW}$line${RESET}"
    else
      echo "$line"
    fi
  done < "$DIFF_FILE"
fi
