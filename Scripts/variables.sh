#!/usr/bin/env sh

###############################################################################
## Text Signs
###############################################################################

if [ $CI ]; then
    alarm="  \033[30;41m ! \033[0m →"
    checkmark="  \033[30;42m x \033[0m →"
    crossmark="  \033[30;41m x \033[0m →"
    info="  \033[30;44m i \033[0m →"
    questionmark="  \033[30;43m ? \033[0m →"
else
    alarm="  \033[30;41m \u23F0 \033[0m →"
    checkmark="  \033[30;42m \xE2\x9C\x94 \033[0m →"
    crossmark="  \033[30;41m \xE2\x9C\x98 \033[0m →"
    info="  \033[30;44m \xE2\x84\xB9 \033[0m →"
    questionmark="  \033[30;43m \xE2\x84\xB9 \033[0m →"
fi

###############################################################################
## Styling functions
###############################################################################

h1() {
    local len=${#1}
    local line=$(printf '%*s' "$len" '' | tr ' ' ' ')
    printf "\n\033[1;30;44m%s\033[0m\n\033[1;30;44m%s\033[0m\n\033[1;30;44m%s\033[0m\n" "$line    " "  $1  " "$line    "
}
h2() {
    printf "\n\033[30;47m\033[0m\033[30;47m%s\033[0m\033[30;47m\033[0m\n" "  $1  "
}
h3() {
    printf "\n\033[30;43m\033[0m\033[30;43m%s\033[0m\033[30;43m\033[0m\n" "  $1  "
}

info() {
    printf "$info\t%s\n" "$1"
}
success() {
    printf "$checkmark\t%s\n" "$1"
}
warning() {
    printf "$questionmark\t%s\n" "$1"
}
error() {
    printf "$crossmark\t%s\n" "$1"
    exit 1
}

logo() {
    printf "\n\033[1;30;44m\033[0m\033[1;30;44m%s\033[0m\033[1;30;44m\033[0m\n" "  TTN Leipzig  "
    printf "\n"
}

###############################################################################
## Variables
###############################################################################

# Get current date in format DD.MM.YYYY
document_date=$(date +%d.%m.%Y)

# Get current year in format YYYY
document_date_year=$(date +%Y)

# Get latest git tag
document_git_tag=$(git describe --tags --abbrev=0)
