#!/usr/bin/env zsh
#==============================================================================
# title   :publish.zsh
# version :0.0.0
# desc    :Publish distribution packages to a github release
# usage   :See below header
# exit    :0=success, 1=input error 2=execution error
# auth    :Tate Hanawalt(tate@tatehanawalt.com)
# date    :1621476898
#==============================================================================
# Builiding:
# 1. Aquire dependencies:
#   - Your Github Username
#   - The full path of the th_sys directory
#   - The full path of the homebrew-devtools directory
#   - Github Personal Access Token for uploading the packages.
#     Instructions:
#       1. Log in to Github
#       2. navigate to https://github.com/settings/tokens
#          This url is: Github -> settings -> Developer Settings
#       3. In the left menu select 'Personal Access tokens'
#       4. On the right, select 'Generate New Token'
#==============================================================================

prnitf "PUBLISH\n"
#     Instructions:
#       1. Log in to Github
#       2. navigate to https://github.com/settings/tokens
#          This url is: Github -> settings -> Developer Settings
#       3. In the left menu select 'Personal Access tokens'
#       4. On the right, select 'Generate New Token'
# - Github Personal Access Token for uploading the packages.
# - Your Github Username
