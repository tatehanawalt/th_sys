#!/usr/bin/env zsh
#==============================================================================
# title   :build.zsh
# version :0.0.0
# desc    :Manage project packager scripts during distribution packaging
# usage   :See below header
# exit    :0=success, 1=input error 2=execution error
# auth    :Tate Hanawalt(tate@tatehanawalt.com)
# date    :1621476898
#==============================================================================
# TLDR:
#
# Call this script with 1 argument - the build version.
#
# Each project has a script that packages the project into a tar archive
# This file calls that script for each project being built. Packagers are
# called with ARGS:
#
#   $1: Full path to the project
#   $2: Directory where the project pacckager placces the packaged archive on success
#   $3: The Build Version (same across all packages)
#
# Packagers exith with code 0 on successful
# Any exit code that is NOT a 0 indicates an failure or error of some kind
# This script exits immedietly if any packager fails
# -----------------------------------------------------------------------------
# Overview:
# Projects are packaged for distribution as .tar.gz archives. Each project
# contains a script responsible for packaging that projects distribution archive.
#
# The th_sys/bin/build.zsh script:
#
#   • Determines the build output directory
#   • Removes any existing items from that directory
#   • Determins which projects need to be packaged
#   • Exits immedietly after any packager fails
#   • Calls project packagers sequentially (for the time being)
#   • does NOT validate format of returned archives
#   • Does verify a packager that exited succesfully delivered a file
#     titled <package_name>.tar.gz to the build output directory
#   • Call project packagers with arguments ordered and formatted the same as
#      every other packager
#
# Every project's packager script (or binary executable) is expected to:
#
#   • Be located at <project_name>/bin/pack
#   • Indicate success by existing with exit code 0
#   • Indicate Errors/Failures by exiting with an exit code that is not 0
#   • Handle arguments in the same order & format as all other
#     project pacckagers
#
# Packager Arguments:
#
#   1. full path of the project (including the project name)
#   2. full-path of the output directory
#   3. The build version
#
# IF SUCCESSFUL: the demoassembly packager is expected to place a 'demoassembly.tar.gz' in the
#                build output directory (Arg 2)
#==============================================================================

# projects to be packaged
local BUILD_PROJECTS=(
  # democ
  democpp
  demonodejs
  demogolang
  demopython
  demozsh
)

# Check that the build script was called with the build version
if [ ${#@} -ne 1 ]; then
  printf "ERROR - th_sys/bin/build.zsh incorrect arguments count. expects \$1=BUILD_VERSION. got ${#@} Arguments\n"
  return 1
fi

local VERSION="$1"

# make sure the build version is not nothing (TODO: add regex for SEMVER format)
if [ -z "${#@}" ]; then
  printf "ERROR - th_sys/bin/build.zsh build version not specified\n"
  return 1
fi

# We need a minimum of 1 project to go furth
if [ ${#BUILD_PROJECTS} -lt 1 ]; then
  printf "ERROR - th_sys/bin/build.zsh packager called with 0 projects\n"
  return 1
fi

# Get the root path of the git repository
REPOSITORY_ROOT_PATH=$(git rev-parse --show-toplevel)
if [ -z "$REPOSITORY_ROOT_PATH" ]; then
  printf "ERROR - th_sys build.zsh failed to locate the root repository path\n"
  return 1
fi

# Get the name of the repository
REPOSITORY_NAME=$(basename "$REPOSITORY_ROOT_PATH")
if [[ "$REPOSITORY_NAME" != "th_sys" ]]; then
  printf "ERROR - th_sys build.zsh must be executed in the th_sys repository\n"
  return 1
fi

# buld out path
local BUILD_PATH="$REPOSITORY_ROOT_PATH/out"

# do NOT remove anything that is not a direcctory...
if [ -z "$BUILD_PATH" ]; then
  printf "ERROR - th-sys BUILd_PATH is somehow empty\n"
  return 2
fi

# do NOT remove anything that is not a direcctory...
if [ -f "$BUILD_PATH" ]; then
  printf "ERROR - th-sys build.zsh build_path is a file not a directory at $BUILD_PATH\n"
  return 1
fi

# Print the build valid build parameters, then invoke the project packagers
printf "REPOSITORY_NAME:      %s\n" $REPOSITORY_NAME
printf "REPOSITORY_ROOT_PATH: %s\n" $REPOSITORY_ROOT_PATH
printf "BUILD_PATH:           %s\n" $BUILD_PATH

#  Clean the build path
[ -d "$BUILD_PATH" ] && rm -r "$BUILD_PATH"
mkdir "$BUILD_PATH"

#
printf "PROJECTS: %d\n" ${#BUILD_PROJECTS}
printf " - %s\n" $BUILD_PROJECTS
printf "\n"

# For each project in the 'BUILD_PROJECTS' array, call the projects package script:
for ((i=1;i<=${#BUILD_PROJECTS};i++)); do

  # Path to specific cli directory
  local PROJECT_ROOT="$REPOSITORY_ROOT_PATH/$BUILD_PROJECTS[$i]"
  local PROJECT_PACKAGER="$PROJECT_ROOT/bin/build"

  # Check that the build script is executabble
  if [ ! -x "$PROJECT_PACKAGER" ]; then
    printf "ERROR - $BUILD_PROJECTS[$i]' packager $PROJECT_PACKAGER missing executable permissions\n"
    return 2
  fi

  # Make sure the out path is a directory
  if [ ! -d "$BUILD_PATH" ]; then
    printf "ERROR: project '$BUILD_PROJECTS[$i]' build path is not a directory at BUILD_PATH=%s\n" "$BUILD_PATH"
    return 2
  fi

  # Call the project packager
  $PROJECT_PACKAGER "$PROJECT_ROOT" "$BUILD_PATH" "$VERSION"
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    printf "ERROR: project '$BUILD_PROJECTS[$i]' build script NON-ZERO exit_code=$exit_code\n"
    return 2
  fi

  # Make sure the package landed where we expected it since the packer exited successfully
  if [ ! -f "$BUILD_PATH/$BUILD_PROJECTS[$i].tar.gz" ]; then
    printf "ERROR: project '$BUILD_PROJECTS[$i]' distribution package not found at "$BUILD_PATH/$BUILD_PROJECTS[$i].tar.gz"\n"
    return 2
  fi

  printf "\n"
done
