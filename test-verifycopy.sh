#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test-tmp"
SOURCE="$TEST_DIR/source"
DEST="$TEST_DIR/dest"
SCRIPT_CMD="$SCRIPT_DIR/verifycopy.zsh"
DIFF_FILE="$SCRIPT_DIR/verifycopy_diff_output.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

declare -a TEST_RESULTS
declare -a TEST_NAMES

setup_env() {
  rm -rf "$SOURCE" "$DEST"
  mkdir -p "$SOURCE" "$DEST"
  rm -f "$DIFF_FILE"
}

record_result() {
  local desc="$1"
  local expect_diff="$2"

  if [[ "$expect_diff" == "yes" ]]; then
    [[ -s "$DIFF_FILE" ]] && TEST_RESULTS+=("PASS") || TEST_RESULTS+=("FAIL")
  else
    [[ ! -s "$DIFF_FILE" ]] && TEST_RESULTS+=("PASS") || TEST_RESULTS+=("FAIL")
  fi
  TEST_NAMES+=("$desc")
}

run_test() {
  local description="$1"
  local test_func="$2"
  local expect_diff="$3"

  echo -e "\n${YELLOW}=== TEST: $description ===${RESET}"
  setup_env
  $test_func

  $SCRIPT_CMD <<EOF
$SOURCE
$DEST
yes
EOF

  echo -e "${YELLOW}Diff file output:${RESET}"
  cat "$DIFF_FILE" 2>/dev/null || echo "(no diff output)"
  echo ""

  record_result "$description" "$expect_diff"
}

# ====== TEST CASES ======

# ✅ Test 1: Identical files — perfect copy, should PASS
test_identical_files() {
  echo "hello world" > "$SOURCE/same.txt"
  cp "$SOURCE/same.txt" "$DEST/"
}

# ✅ Test 2: File missing in destination — must be caught
test_missing_in_dest() {
  echo "only in source" > "$SOURCE/unique.txt"
}

# ✅ Test 3: File missing in source — must be caught
test_missing_in_source() {
  echo "only in dest" > "$DEST/extra.txt"
}

# ✅ Test 4: Changed content, same name & timestamp, different size
# Detected because size differs (timestamp remains unchanged)
test_changed_file_size_diff() {
  echo "foo" > "$SOURCE/same.txt"
  echo "barbar" > "$DEST/same.txt"
}

# ✅ Test 5: Same name & content, same size, different timestamp
# Detected only if timestamp check is enabled
test_same_content_diff_timestamp() {
  echo "timestamp test" > "$SOURCE/same.txt"
  cp "$SOURCE/same.txt" "$DEST/same.txt"
  touch -t 202201010000 "$SOURCE/same.txt"
  touch -t 202301010000 "$DEST/same.txt"
}

# ✅ Test 6: Same name, size, and timestamp, but different content
# NOT detected — intentional false negative (due to no checksum)
test_changed_file_same_everything() {
  echo "abcdefg" > "$SOURCE/same.txt"
  echo "abcxefg" > "$DEST/same.txt"
  touch -r "$SOURCE/same.txt" "$DEST/same.txt"
}

# ✅ Test 7: Different filename, same content and timestamp
# Must be caught due to path mismatch
test_different_filename_same_content() {
  echo "same content" > "$SOURCE/file1.txt"
  echo "same content" > "$DEST/file2.txt"
  touch -t 202201010000 "$SOURCE/file1.txt"
  touch -t 202201010000 "$DEST/file2.txt"
}

# ✅ Test 8: Same name and size, different content and timestamp
# Detected only if timestamp check is enabled
test_diff_content_same_size_diff_time() {
  echo "abc1234" > "$SOURCE/file.txt"
  echo "xyz1234" > "$DEST/file.txt"
  touch -t 202201010000 "$SOURCE/file.txt"
  touch -t 202301010000 "$DEST/file.txt"
}

# ✅ Test 9: Nested directories — must compare recursively
test_nested_directories() {
  mkdir -p "$SOURCE/deep/nested"
  echo "deep content" > "$SOURCE/deep/nested/file.txt"
  mkdir -p "$DEST/deep/nested"
  cp "$SOURCE/deep/nested/file.txt" "$DEST/deep/nested/"
}

# ✅ Test 10: AppleDouble (._*) only in source — must be ignored
test_apple_double_only_in_source() {
  echo "appledouble metadata" > "$SOURCE/._junk.txt"
  touch -t 202201010000 "$SOURCE/._junk.txt"
}

# ✅ Test 11: DS_Store differs in both folders — must be ignored
test_ds_store_differing() {
  echo "source-ds" > "$SOURCE/.DS_Store"
  echo "dest-ds" > "$DEST/.DS_Store"
  touch -t 202201010000 "$SOURCE/.DS_Store"
  touch -t 202301010000 "$DEST/.DS_Store"
}

# ✅ Test 12: Timestamp check disabled — must NOT detect time-only mismatch
test_disable_timestamp_check() {
  setup_env
  echo "time-based" > "$SOURCE/same.txt"
  cp "$SOURCE/same.txt" "$DEST/"
  touch -t 202101010000 "$SOURCE/same.txt"
  touch -t 202201010000 "$DEST/same.txt"

  echo -e "\n${YELLOW}Running without timestamp check...${RESET}"
  $SCRIPT_CMD <<EOF
$SOURCE
$DEST
no
EOF

  echo -e "${YELLOW}Diff file (no timestamp check):${RESET}"
  cat "$DIFF_FILE" 2>/dev/null || echo "(no diff output)"
  echo ""

  record_result "12. Disable timestamp check (time-only change should pass)" "no"
}

# ====== RUN TESTS ======
run_test "1. Identical files" test_identical_files "no"
run_test "2. Missing file in destination" test_missing_in_dest "yes"
run_test "3. Missing file in source" test_missing_in_source "yes"
run_test "4. Changed content (different size, same timestamp)" test_changed_file_size_diff "yes"
run_test "5. Same content, different timestamp (timestamp check must catch)" test_same_content_diff_timestamp "yes"
run_test "6. Same name, size, timestamp, different content (false negative)" test_changed_file_same_everything "no"
run_test "7. Different filename, same content" test_different_filename_same_content "yes"
run_test "8. Different content, same size, different timestamp (timestamp check must catch)" test_diff_content_same_size_diff_time "yes"
run_test "9. Nested directory structure" test_nested_directories "no"
run_test "10. AppleDouble file only in source (ignored)" test_apple_double_only_in_source "no"
run_test "11. DS_Store differs (ignored)" test_ds_store_differing "no"
test_disable_timestamp_check

# ====== SUMMARY ======
echo -e "\n${YELLOW}========== TEST SUMMARY ==========${RESET}"
total=${#TEST_RESULTS[@]}
pass_count=0
for i in "${!TEST_RESULTS[@]}"; do
  result="${TEST_RESULTS[$i]}"
  name="${TEST_NAMES[$i]}"
  if [[ "$result" == "PASS" ]]; then
    echo -e "✅ ${GREEN}PASS${RESET} — $name"
    ((pass_count++))
  else
    echo -e "❌ ${RED}FAIL${RESET} — $name"
  fi
done
echo -e "${YELLOW}==================================${RESET}"
echo -e "${GREEN}Passed: $pass_count / $total${RESET}"

# ====== CLEANUP ======
echo -e "\n${GREEN}Cleaning up test folders...${RESET}"
rm -rf "$TEST_DIR"
