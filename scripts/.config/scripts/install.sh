#!/bin/bash

set -e

while getopts ":d:" opt; do
  case ${opt} in
  d)
    INPUT_FILE="$OPTARG"
    ;;
  \?)
    echo "❌ Unknown option: -$OPTARG" >&2
    exit 1
    ;;
  :)
    echo "❌ Option -$OPTARG requires a file path." >&2
    exit 1
    ;;
  esac
done

if [ -z "$INPUT_FILE" ]; then
  echo "❌ Please provide the input file using -d flag."
  echo "Example: ./install.sh -d brew_packages.txt"
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "❌ File '$INPUT_FILE' not found."
  exit 1
fi

# 🍺 Install Homebrew if not installed
if ! command -v brew &>/dev/null; then
  echo "🍺 Homebrew not found, installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)" # for Apple Silicon
fi

echo "📦 Installing packages from $INPUT_FILE..."

while IFS=: read -r package type; do
  package=$(echo "$package" | xargs)
  type=$(echo "$type" | xargs)

  if [ -z "$package" ] || [ -z "$type" ]; then
    continue
  fi

  if [ "$type" = "formula" ]; then
    if brew list --formula | grep -qx "$package"; then
      echo "✅ Formula '$package' is already installed."
    else
      echo "📦 Installing formula: $package"
      brew install "$package" || echo "⚠️ Failed to install $package"
    fi
  elif [ "$type" = "cask" ]; then
    if brew list --cask | grep -qx "$package"; then
      echo "✅ Cask '$package' is already installed."
    else
      echo "🖥️ Installing cask: $package"
      brew install --cask "$package" || echo "⚠️ Failed to install $package"
    fi
  else
    echo "⚠️ Unknown type for package: $package ($type)"
  fi
done <"$INPUT_FILE"

echo "🎉 Done!"
