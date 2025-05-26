#!/bin/bash

# Directory containing the files (default to current directory if not provided)
DIR="${1:-.}"
# Base name for the new files
BASE_NAME="${2:-Wallpaper}"
# Counter starting number
COUNTER=1

# Check if the directory exists
if [ ! -d "$DIR" ]; then
  echo "Error: Directory '$DIR' not found."
  exit 1
fi

echo "Renaming files in '$DIR' with base name '$BASE_NAME'"

# Use fd to find files in the directory. Adjust '.' to filter file types if needed (e.g., fd -e png).
# -0 option is used for null termination to handle filenames with spaces or special characters.
fd -e png "$DIR" -0 | while IFS= read -r -d $'' old_file; do
  # Check if it's a regular file (not a directory, etc.)
  if [ -f "$old_file" ]; then
    # Construct the new filename, forcing .png extension as requested
    new_file="${DIR}/${BASE_NAME}_${COUNTER}.png"

    # Only rename if the new name is different from the old name
    if [ "$old_file" != "$new_file" ]; then
      echo "Renaming '$old_file' to '$new_file'" # Optional: show what's being renamed
      mv "$old_file" "$new_file"
    fi

    # Increment the counter
    COUNTER=$((COUNTER + 1))
  fi
done

echo "Renaming complete."
