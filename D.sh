#!/bin/bash


function select_option {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}





red="\e[0;91m"
green="\e[0;92m"
blue="\e[0;94m"

reset="\e[0m"

clear
echo -e "${red}Lando Drupal Site Generator${reset}"

clear
echo -e "${blue}Creating new Drupal site${reset}"

read -p 'Sitename [Dev]: ' sitename
sitename=${sitename:-Dev}
clear
echo -e "${blue}Creating new Drupal site${reset}"
echo -e "Sitename : ${red}$sitename${reset}"
read -p "Username [Admin]: " username
username=${username:-Admin}

clear
echo -e "${blue}Creating new Drupal site${reset}"
echo -e "Sitename : ${red}$sitename${reset}"
echo -e "Username : ${red}$username${reset}"

while true; do
    read -p 'Email [someone@somewhere.com]: ' email
    email=${email:-someone@somewhere.com}
    if [ -z "$email" ]; then
     echo "Please enter an email address!";
    else
     break;
    fi  
done

clear
echo -e "${blue}Creating new Drupal site${reset}"
echo -e "Sitename : ${red}$sitename${reset}"
echo -e "Username : ${red}$username${reset}"
echo -e "Email : ${red}$email${reset}"


while true; do
    read -p 'Password [1234]: ' password
    password=${password:-1234}
    if [ -z "$password" ]; then
     echo "Please enter a password!";
    else
     break;
    fi  
done

clear
echo -e "${blue}Creating new Drupal site${reset}"
echo -e "Sitename : ${red}$sitename${reset}"
echo -e "Username : ${red}$username${reset}"
echo -e "Email : ${red}$email${reset}"
echo -e "Password : ${red}$password${reset}"
echo "Select a Drupal version"
echo

options=(
 10.1.x-dev
 10.0.x-dev
 10.0.3
 10.0.2
 10.0.1
 10.0.0
 9.5.0
 9.4.0
 9.2.0
 9.1.0
 9.0.0
 8.9.0
 8.8.0
)

select_option "${options[@]}"
choice=$?

clear
echo -e "${blue}Creating new Drupal site${reset}"
echo -e "Sitename : ${red}$sitename${reset}"
echo -e "Username : ${red}$username${reset}"
echo -e "Email : ${red}$email${reset}"
echo -e "Password : ${red}$password${reset}"
echo -e "Drupal version : ${red}${options[$choice]}${reset}"

version=${options[$choice]}

versionfirstchar=${version:0:1}

# Create drupal project 
composer create-project drupal/recommended-project:$version $sitename

# Change to new root directory
cd $sitename

# Add patches and config directorys
mkdir patches
mkdir config

# Create lando init file
lando init \
  --source cwd \
  --recipe 'drupal'$versionfirstchar \
  --webroot web \
  --name $sitename

# Add extra bits to .lando.yml file
sed -i "$ a\  xdebug: true\ntooling:\n  drush:\n    service: appserver\n    env:\n       DRUSH_OPTIONS_URI: "https://$sitename.lndo.site"\nservices:\n appserver:\n  type: php:8.1\n  build:\n   - composer install" .lando.yml

# Start lando
lando start

# Install drush and other useful modules
lando composer require drush/drush
lando composer require drupal/admin_toolbar
lando composer require drupal/token
lando composer require drupal/devel
lando composer require cweagans/composer-patches


# Update composer
lando composer update

# Install Drupal using Lando details
lando drush si standard \
  --db-url='mysql://drupal'$versionfirstchar':drupal'$versionfirstchar'@database:3306/drupal'$versionfirstchar -y \
  --account-name=Admin --account-pass=$password \
  --site-name=$sitename \
  --site-mail=$email \

echo "Drupal site installed !"

# Enable custom modules
lando drush en admin_toolbar
lando drush en admin_toolbar_tools
lando drush en media
lando drush en media_library
lando drush en layout_builder -y
lando drush en token
lando drush en devel
lando drush en devel_generate

# Clear the cache
lando drush cr

# Add recommended drupal 9 gitignore file 
curl -o .gitignore 'https://raw.githubusercontent.com/drupal/drupal/9.3.x/example.gitignore'

# Change .gitignore permissions
chmod 644 .gitignore

# Clear the cache
lando drush cr








