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
printf "\t- COOKBOOK: https://docs.brew.sh/Formula-Cookbook\n"

printf "\n"
printf "\tWORKFLOWS:\n"
printf "\t- EXAMPLES: https://github.com/actions/starter-workflows\n"
printf "\t- ABOUT:    https://docs.github.com/en/actions/creating-actions/about-actions\n"


printf "\n"
printf "INFO: eventually this will cover details on the env and instructions\n"
printf "      for testing the source code. right now its mostly just notes\n"
