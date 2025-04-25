#!/bin/bash

# --- Configuration ---
DEFAULT_EXCLUDE_DIRS=(".git") # Directories to exclude by default
TARGET_PATH="."                  # Default directory to run tree on
OUTPUT_FILE=".PROJECT_DUMP_TEXT_ENHANCED_TREE.txt"                   # Default: print to stdout

# --- Arrays for User Exclusions ---
USER_EXCLUDE_DIRS=(".import" "addons")
USER_EXCLUDE_EXTS=(".sh" ".md" ".import" ".json" ".ico" ".gitignore" ".txt")

# --- Function Definitions ---

# Print usage instructions
usage() {
  echo "Usage: $0 [-p <path>] [-d <dir1,dir2,...>] [-e <ext1,ext2,...>] [-o <output_file>] [-h]"
  echo ""
  echo "  Generates a directory tree structure similar to the 'tree' command,"
  echo "  with enhanced exclusion options."
  echo ""
  echo "  Options:"
  echo "    -p <path>          : Target directory to generate the tree for (default: .)"
  echo "    -d <dir_list>      : Comma-separated list of additional directory names to exclude."
  echo "                         (Default exclusions: ${DEFAULT_EXCLUDE_DIRS[*]})"
  echo "    -e <ext_list>      : Comma-separated list of file extensions to exclude (e.g., log,tmp,bak)."
  echo "    -o <output_file>   : File to write the output tree to (default: print to standard output)."
  echo "    -h                 : Display this help message."
  echo ""
  echo "  Requires the 'tree' command to be installed."
  exit 1
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Argument Parsing ---
while getopts "p:d:e:o:h" opt; do
  case $opt in
    p) TARGET_PATH="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    d) IFS=',' read -r -a USER_EXCLUDE_DIRS <<< "$OPTARG" ;;
    e) IFS=',' read -r -a USER_EXCLUDE_EXTS <<< "$OPTARG" ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND-1))

# --- Validation ---

# Check if tree command exists
if ! command_exists tree; then
  echo "Error: 'tree' command not found. Please install it (e.g., 'sudo apt install tree')." >&2
  exit 1
fi

# Check if target path exists and is a directory
if [ ! -d "$TARGET_PATH" ]; then
  echo "Error: Target path '$TARGET_PATH' not found or is not a directory." >&2
  exit 1
fi

# --- Build Exclusion Pattern ---

all_exclude_patterns=()

# Add default directory exclusions
all_exclude_patterns+=("${DEFAULT_EXCLUDE_DIRS[@]}")

# Add user-specified directory exclusions
all_exclude_patterns+=("${USER_EXCLUDE_DIRS[@]}")

# Add user-specified extension exclusions (formatted as *.ext)
for ext in "${USER_EXCLUDE_EXTS[@]}"; do
  # Remove leading dot if present, handle empty strings
  clean_ext="${ext#.}"
  if [ -n "$clean_ext" ]; then
      all_exclude_patterns+=("*.${clean_ext}")
  fi
done

# Create the final pattern string for tree's -I option (items separated by |)
# Filter out empty elements just in case before joining
ignore_pattern=$(printf "%s\n" "${all_exclude_patterns[@]}" | grep . | paste -sd '|')

# --- Construct and Run Tree Command ---

tree_cmd=("tree")

# Use -a to include hidden files/dirs (like .env), but .git etc will be excluded by -I
tree_cmd+=("-a")

# Use --prune so -I applies to directories, preventing descent into them
tree_cmd+=("--prune")

# Add the ignore pattern if it's not empty
if [ -n "$ignore_pattern" ]; then
  echo "Applying exclusions: $ignore_pattern"
  tree_cmd+=("-I" "$ignore_pattern")
else
  echo "No exclusions applied."
fi

# Add the target path
tree_cmd+=("$TARGET_PATH")

# --- Execute and Handle Output ---

echo "Generating tree for '$TARGET_PATH'..."
echo "----------------------------------------"

# Execute the command
if [ -n "$OUTPUT_FILE" ]; then
  # Write to file
  if "${tree_cmd[@]}" > "$OUTPUT_FILE"; then
    echo "Tree structure saved to '$OUTPUT_FILE'"
    # Add the final report (directory/file count) from tree to the file as well
    tree_report=$("${tree_cmd[@]}" | tail -n 1) # Rerun to capture only the report line
    echo "" >> "$OUTPUT_FILE"
    echo "$tree_report" >> "$OUTPUT_FILE"
    echo "Report appended."
  else
    echo "Error running tree command. Output file may be incomplete." >&2
    exit 1
  fi
else
  # Print to stdout
  "${tree_cmd[@]}"
  # Check exit status if needed
  if [ $? -ne 0 ]; then
     echo "Error running tree command." >&2
     exit 1
  fi
fi

echo "----------------------------------------"
echo "Done."

exit 0
