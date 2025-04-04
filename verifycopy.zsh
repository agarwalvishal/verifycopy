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

echo -n "Do you want to check timestamps as well? (yes/no) [yes]: "
read CHECK_TIMESTAMP_INPUT

if [[ "$CHECK_TIMESTAMP_INPUT" =~ ^[Nn](o)?$ ]]; then
  CHECK_TIMESTAMP=false
else
  CHECK_TIMESTAMP=true
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

# === Resolve actual script directory using readlink ===
SCRIPT_PATH="$0"
if [ -L "$SCRIPT_PATH" ]; then
  LINK_TARGET=$(readlink "$SCRIPT_PATH")
  [[ "$LINK_TARGET" != /* ]] && LINK_TARGET="$(dirname "$SCRIPT_PATH")/$LINK_TARGET"
  SCRIPT_PATH="$LINK_TARGET"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DIFF_FILE="$SCRIPT_DIR/verifycopy_diff_output.txt"
: > "$DIFF_FILE"

# === Function to scan a folder ===
scan_folder() {
  local FOLDER="$1"
  local OUTPUT="$2"
  local INCLUDE_TIMESTAMP="$3"

  cd "$FOLDER" || return 1

  if [[ "$INCLUDE_TIMESTAMP" == "true" ]]; then
    find . -type f ! -name '._*' ! -name '.DS_Store' -exec stat -f "%N %z %m" {} \; | sort > "$OUTPUT"
  else
    find . -type f ! -name '._*' ! -name '.DS_Store' -exec stat -f "%N %z" {} \; | sort > "$OUTPUT"
  fi
}

# === SCAN FOLDERS ===
echo "${YELLOW}Scanning source...${RESET}"
scan_folder "$SOURCE" "$TMP_SRC" "$CHECK_TIMESTAMP"

echo "${YELLOW}Scanning destination...${RESET}"
scan_folder "$DEST" "$TMP_DST" "$CHECK_TIMESTAMP"

echo "${YELLOW}Comparing files...${RESET}"

# === LOAD FILE LISTINGS INTO MAPS ===
typeset -A source_map
typeset -A dest_map

# Load source entries
while IFS= read -r line; do
  key="${line%% *}"  # Extract relative file path
  source_map["$key"]="$line"
done < "$TMP_SRC"

# Load destination entries
while IFS= read -r line; do
  key="${line%% *}"
  dest_map["$key"]="$line"
done < "$TMP_DST"

# === COMPARE FILES ===
all_keys=( ${(k)source_map} ${(k)dest_map} )
all_keys=( ${(u)all_keys} )

for key in $all_keys; do
  src="${source_map[$key]}"
  dst="${dest_map[$key]}"
  if [[ -n "$src" && -n "$dst" ]]; then
    if [[ "$src" != "$dst" ]]; then
      echo "CHANGED: $src → $dst" >> "$DIFF_FILE"
    fi
  elif [[ -n "$src" ]]; then
    echo "MISSING in DEST: $src" >> "$DIFF_FILE"
  elif [[ -n "$dst" ]]; then
    echo "MISSING in SOURCE: $dst" >> "$DIFF_FILE"
  fi
done

# === CLEANUP TEMP FILES ===
rm -f "$TMP_SRC" "$TMP_DST"

# === RESULT OUTPUT ===
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
