#!/bin/bash

OUTPUT_FILE="brew_packages.txt"

echo "🔍..."

brew list --formula | while read -r pkg; do
  echo "$pkg: formula"
done >"$OUTPUT_FILE"

brew list --cask | while read -r pkg; do
  echo "$pkg: cask"
done >>"$OUTPUT_FILE"

echo "✅ the list saved to : $OUTPUT_FILE"
