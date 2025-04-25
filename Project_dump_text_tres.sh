#!/bin/bash

# --- Script Identification ---
SCRIPT_NAME=$(basename "$0")

# Default values
INPUT_DIR="."
OUTPUT_FILE=".PROJECT_DUMP_TEXT_TRES.txt" # Default output, will be excluded
FILE_EXTENSION="tres" # Default file extension
EXCLUDE_WORDS=()
EXCLUDE_DIRS=(".git" "addons" "tests") # Exclude .git by default
ADD_SEPARATOR=true
EXTRACTION_METHOD="cat" # Auto-detect: pandoc -> lynx -> cat

# --- Function Definitions ---

# Print usage instructions
usage() {
  echo "Usage: $0 [-i <input_dir>] [-o <output_file>] [-e <extension>] [-w <word1,word2,...>] [-d <dir1,dir2,...>] [-s] [-h]"
  echo "  Concatenates files 'as is' (raw content) into a single output file."
  echo ""
  echo "  Options:"
  echo "    -i <input_dir>   : Directory to search for files (default: .)"
  echo "    -o <output_file> : File to save combined raw text (default: COMBINED_RAW_FILES.txt)"
  echo "                     (This output file itself will be excluded from processing)"
  echo "    -e <extension>   : File extension to process (default: md)"
  echo "    -w <word_list>   : Comma-separated list of words to exclude *entire lines* containing them."
  echo "    -d <dir_list>    : Comma-separated list of directory names to exclude (e.g., node_modules,build)"
  echo "                     (.git is excluded by default)"
  echo "    -s               : Add a separator line between content from different files"
  echo "    -h               : Display this help message"
  echo ""
  echo "Note: The script file '$SCRIPT_NAME' and the output file will always be excluded."
  exit 1
}

# Check if a command exists (still useful for find, grep, sort)
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Text Extraction (Now always uses cat) ---
extract_text() {
  local file="$1"
  cat "$file"
}

# --- Argument Parsing ---

while getopts "i:o:e:w:d:sh" opt; do
  case $opt in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    e) FILE_EXTENSION="$OPTARG" ;;
    w) IFS=',' read -r -a EXCLUDE_WORDS <<< "$OPTARG" ;;
    d) # Append user-specified dirs to the default .git exclusion
       IFS=',' read -r -a user_exclude_dirs <<< "$OPTARG"
       EXCLUDE_DIRS+=("${user_exclude_dirs[@]}")
       ;;
    s) ADD_SEPARATOR=true ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND-1))

# --- Validation ---

if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: Input directory '$INPUT_DIR' not found." >&2
  exit 1
fi

# Remove leading dot from extension if present
FILE_EXTENSION="${FILE_EXTENSION#.}"
if [ -z "$FILE_EXTENSION" ]; then
    echo "Error: File extension cannot be empty." >&2
    usage
fi

# Check necessary commands exist (find, grep, sort, cat)
for cmd in find grep sort cat; do
    if ! command_exists $cmd; then
        echo "Error: Required command '$cmd' not found." >&2
        exit 1
    fi
done


# Get the basename of the output file for exclusion
OUTPUT_FILE_BASENAME=$(basename "$OUTPUT_FILE")

# --- Exclusion Pattern Generation ---

# Build find's -prune pattern for directories
FIND_EXCLUDE_DIRS_PATTERN=()
unique_exclude_dirs=($(printf "%s\n" "${EXCLUDE_DIRS[@]}" | sort -u)) # Ensure unique

if [ ${#unique_exclude_dirs[@]} -gt 0 ]; then
    echo "Excluding directories: ${unique_exclude_dirs[*]}"
    for dir in "${unique_exclude_dirs[@]}"; do
        if [ -n "$dir" ]; then # Handle potential empty strings
          FIND_EXCLUDE_DIRS_PATTERN+=(-o -path "*/${dir}/*" -o -path "*/${dir}")
        fi
    done
    if [ ${#FIND_EXCLUDE_DIRS_PATTERN[@]} -gt 0 ]; then
        FIND_EXCLUDE_DIRS_PATTERN=("(" "${FIND_EXCLUDE_DIRS_PATTERN[@]:1}" ")" -prune)
    fi
fi


# Build grep's regex pattern for words (will exclude entire lines)
GREP_EXCLUDE_WORDS_PATTERN=""
if [ ${#EXCLUDE_WORDS[@]} -gt 0 ]; then
  GREP_EXCLUDE_WORDS_PATTERN=$(printf '\\b%s\\b\|' "${EXCLUDE_WORDS[@]}")
  GREP_EXCLUDE_WORDS_PATTERN=${GREP_EXCLUDE_WORDS_PATTERN%\|} # Remove trailing '|'
  echo "Excluding lines containing words: ${EXCLUDE_WORDS[*]}"
else
  echo "No line exclusion based on words."
fi

# --- File Processing ---

# Clear/Create the output file
if [ "$OUTPUT_FILE_BASENAME" = "$SCRIPT_NAME" ] && [ "$OUTPUT_FILE" = "$0" ]; then
    echo "Error: Output file cannot be the script file itself ('$SCRIPT_NAME')." >&2
    exit 1
fi
> "$OUTPUT_FILE"
echo "Output file '$OUTPUT_FILE' created/cleared."

echo "Combining raw content of '*.$FILE_EXTENSION' files in: $INPUT_DIR (sorted alphabetically)"
echo "Excluding script '$SCRIPT_NAME' and output file '$OUTPUT_FILE_BASENAME'."
echo "Saving combined raw text to: $OUTPUT_FILE"
echo "----------------------------------------------------"

# Find target files, excluding specified directories AND specific files, sort them, then process
while IFS= read -r file; do
    file_basename=$(basename "$file")
    if [ ! -f "$file" ] || [ "$file_basename" = "$SCRIPT_NAME" ] || [ "$file_basename" = "$OUTPUT_FILE_BASENAME" ]; then
        continue
    fi

    echo "Processing: $file"

    # Add separator BEFORE file content if requested (and if not the first file)
    # This avoids a leading separator. Check if output file is non-empty.
    if [ "$ADD_SEPARATOR" = true ] && [ -s "$OUTPUT_FILE" ]; then
        echo -e "\n--- Start of $file ---\n" >> "$OUTPUT_FILE"
    # Add a marker for the very first file if separator is enabled
    elif [ "$ADD_SEPARATOR" = true ]; then
         echo -e "--- Start of $file ---\n" >> "$OUTPUT_FILE"
    fi


    # Extract raw text using cat
    extracted_text=$(extract_text "$file")
    exit_status=$? # Check cat's exit status

    if [ $exit_status -ne 0 ]; then
        echo "Warning: Failed to read file '$file' (exit code: $exit_status)." >&2
        # Optionally add a separator note even on failure if separator is enabled
        if [ "$ADD_SEPARATOR" = true ]; then
           echo -e "\n--- Failed to read $file ---\n" >> "$OUTPUT_FILE"
        fi
        continue # Skip to the next file
    fi

    # Filter out excluded words if any are specified (operates on whole lines now)
    if [ -n "$GREP_EXCLUDE_WORDS_PATTERN" ]; then
        printf '%s\n' "$extracted_text" | grep -vE -- "$GREP_EXCLUDE_WORDS_PATTERN" >> "$OUTPUT_FILE"
    else
        # Append raw content directly
        printf '%s\n' "$extracted_text" >> "$OUTPUT_FILE"
    fi

    # Separator logic moved to the top for better placement between files

# Find, prune, exclude, print, sort
done < <(find "$INPUT_DIR" \
            -type d "${FIND_EXCLUDE_DIRS_PATTERN[@]}" -o \
            \( \
                -type f \
                -name "*.${FILE_EXTENSION}" \
                \! -name "$SCRIPT_NAME" \
                \! -name "$OUTPUT_FILE_BASENAME" \
            \) -print \
         | sort)

echo "----------------------------------------------------"
echo "Combined raw text saved to $OUTPUT_FILE"

exit 0
