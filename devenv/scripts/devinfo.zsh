#!/usr/bin/env zsh

printf "\n\n"
printf "LOCAL:\n"
printf "DEV ENVIRONMENT:\n\n"

printf "Keg - formula namespace (found in /usr/local/Cellar)\n\n"

output_lines=(${(@f)"$(ls -l /usr/local/opt)"})

printf " - %s\n" $output_lines

printf "\n"

printf "FORMULA:\n"
printf "\t- API REF:  https://rubydoc.brew.sh/Formula.html\n"
printf "\t- COOKBOOK: https://docs.brew.sh/Formula-Cookbook\n"

printf "\n"
