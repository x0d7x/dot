#!/bin/bash

homebrew_path=/usr/local/bin/brew
dotfile_list=~/dotfiles/my_brew.txt
git_url=https://github.com/d7manDev/dotfiles
all_installed=true
cat << "EOF"

 ____            __    ____                               
/\  _`\         /\ \__/\  _`\                             
\ \ \/\ \    ___\ \ ,_\ \ \L\ \  _ __    __   __  __  __  
 \ \ \ \ \  / __`\ \ \/\ \  _ <'/\`'__\/'__`\/\ \/\ \/\ \ 
  \ \ \_\ \/\ \L\ \ \ \_\ \ \L\ \ \ \//\  __/\ \ \_/ \_/ \
   \ \____/\ \____/\ \__\\ \____/\ \_\\ \____\\ \___x___/'
    \/___/  \/___/  \/__/ \/___/  \/_/ \/____/ \/__//__/  
                                                          
    Github:@d7manDev                   x:@d7g_x                                                      

EOF

# Check if Homebrew is installed
if [ -f "$homebrew_path" ] && [ -e "$dotfile_list" ]; then
  echo "Homebrew is installed ✅"
  echo "my_brew.txt exists ✅"
  while true; do
    read -p "Would you like to install uninstalled packages from my_brew.txt [y/n]? " ans
    case "$ans" in
      [yY]*)
# Read packages from the file and check their installation status
  while IFS= read -r package; do
        echo "checking ${package}...⏳"
    if  ! brew list -1 | grep -q "$package"; then
        status="❌"
        echo "Installing '${package}' ..." 
        xargs brew install "${package}"
        echo "${package} installed " 
      all_installed=false
      else
        status="✅"
    fi
    echo "${package} ${status} "
  done < "$dotfile_list"
  if $all_installed ; then
      echo "all pkgs are installed ✅"
  fi
        break
        ;;
      [nN]*)
        echo "Ok, exiting."
        exit 1
        ;;
      *)
        echo "Invalid input. Please enter 'y' or 'n'."
        ;;
    esac
  done
# Check if dotfiles directory and file exist, but Homebrew not installed
elif ! [ -f "$homebrew_path" ] && [ -e "$dotfile_list" ]; then
  read -p "Homebrew is not installed. Install it now? [y/n]? " answ1

  case "$answ1" in
    [yY]*)
      echo "Installing Homebrew... ⏳"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      bash -c "bash ~/dotfiles/install.sh"  # Assuming an install.sh in your dotfiles
      ;;
    [nN]*)
      echo "Exiting. You can install Homebrew manually."
      exit 1
      ;;
    *)
      echo "Invalid input. Please enter 'y' or 'n'."
      ;;
  esac

# Homebrew installed, but no dotfiles list
else
  read -p "Dotfiles not found. Install dotfiles from $git_url? [y/n]? " answ

  case "$answ" in
    [yY]*)
      echo "Installing dotfiles... ⏳"
      /bin/bash -c "mkdir ~/dotfiles; git clone $git_url ~/dotfiles"
         read -p "done ✅, would you like to copy dotfiles config to \$HOME direcory? [ y/ n ]⇉ " answ4
            if [[ $answ4 == [yY] ]]; then
            bash -c "cd ~/dotfiles/; stow . --adopt"
            echo "you all set 👍 "
            elif [[ $answ4 == [nN] ]]; then
            echo "Bye 👋 "
            exit 1
            else
            read -p "you need to enter y / n " answ4
            fi
      bash -c "bash ~/dotfiles/install.sh"
      ;;
    [nN]*)
      echo "Exiting."
      exit 1
      ;;
    *)
      echo "Invalid input. Please enter 'y' or 'n'."
      ;;
  esac
fi

echo "Done! ✅"
