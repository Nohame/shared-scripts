#!/usr/bin/env sh

# COLORS
# 0    black     BLACK     0,0,0
# 1    red       RED       1,0,0
# 2    green     GREEN     0,1,0
# 3    yellow    YELLOW    1,1,0
# 4    blue      BLUE      0,0,1
# 5    magenta   MAGENTA   1,0,1
# 6    cyan      CYAN      0,1,1
# 7    white     WHITE     1,1,1
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
RESET_COLOR=`tput sgr0`

# Affiche un message sur la sortie standard
display()
{
    echo ">> $@"
}

# Affiche un message d'erreur sur la sortie standard
display_error()
{
    echo ">>${RED} $@${RESET_COLOR}"
}

# Affiche un message de réussite sur la sortie standard
display_success()
{
    echo ">>${GREEN} $@${RESET_COLOR}"
}

display_yellow() {
    echo ">>${YELLOW} $@${RESET_COLOR}"
}

display_bleu() {
    echo ">>${BLUE} $@${RESET_COLOR}"
}

display_green() {
    echo ">>${GREEN} $@${RESET_COLOR}"
}

display_red() {
    echo ">>${RED} $@${RESET_COLOR}"
}

