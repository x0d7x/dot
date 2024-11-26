#! /bin/bash
src=/usr/local/bin/brew
file_path=~/dotfiles/my_brew.txt
# check if homebrew iis installed 
if [[ -e "$src" ]] && [[ -f "$file_path" ]]; then
    cat $file_path
    echo "homebrew is installed ✅ "
    echo "my_brew file is exict ✅ "
    read -p "would you like to install pkgs from my_brew.txt [ y ✅ / n ❌ ]⇉ " ans
    # check for my_brew.txt file
    if [[  $ans == [yY] ]]; then
        echo "installing fourmal && cask from my_brew.txt ⏳📦"
        xargs brew install < ~/dotfiles/my_brew.txt
        read -p " done ✅, would you like to copy dotfiles config to \$HOME direcory? [ y/ n ]⇉ " answ4
        if [[ $answ4 == [yY] ]]; then
            bash -c "cd ~/dotfiles/; stow . --adopt"
            echo "you all set 👍 "
            exit 1
            elif [[ $answ4 == [nN] ]]; then
                echo "Bye 👋 "
                exit 1
            else
                read -p "you need to enter y / n " answ4
        fi

    elif  [[ $ans == [nN] ]];then
        echo "ok 😔 "
        exit 1
    else
        read -p  "you have to enter y / n : " ans
    fi
    # clone dotfiles repo if not
elif [  "$file_path" !=  "\-e $file_path" ] && [ -e "$src" ]; then
        read -p "installing dotfiles 📁... [ y ✅ , n ❌ ]⇉ " answ
        if [ $answ == [yY] ]; then
         /bin/bash -c "git clone https://github.com/d7manDev/dotfiles ~/; bash ~/dotfiles/install.sh"
        else 
        echo "ok see you next time 😔 "
        exit 1
        fi
        # if homebbrew is not install 
elif [ "$src" != "-e $src" ] && [ -e "$file_path" ]; then
           read -p "u don't have homebrew would you install it ? [ y / n ]⇉ " answ1
           if [ $answ1 == [yY] ]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            read -p "homebrew has installed ✅, would you like to get dotfiles repo ? [ y / n ] " answ2
                if [[ $answ2 == [yY] ]]; then
                /bin/bash -c "git clone https://github.com/d7manDev/dotfiles ~/; bash ~/dotfiles/install.sh" 
                elif [ $answ2 == [nN] ]; then
                    echo " Bye 👋 "
                    exit 1
                else
                read -p "you have to answer y / n : " answ2
                fi
            elif [[ $answ1 == [nN] ]]; then
                echo "bye 😔👋 "
                exit 1
            else
                read -p "you have to answer y / n ! " answ1
                
           fi
else
     echo "somthing went wrong... 😔 "
     exit 1
            
fi
