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


printf "PROJECTS: %d\n" ${#BUILD_PROJECTS}
printf " - %s\n" $BUILD_PROJECTS
printf "\n"

# Call the build script for each project
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



return

# --------------------------------------------------------------------------------------------
# DETERMINE THE BUILD SHASUM for the output <out_path>/<project_name>.tar.gz
# --------------------------------------------------------------------------------------------
shaval=$(shasum -a 256 $out_path | sed 's/ .*//g')
if [ $? -ne 0 ]; then
  printf "ERROR: project '$projects[$i]' shaval failed for out_path=$out_path\n"
  return 2
fi
if [ -z "$shaval" ]; then
  printf "ERROR: project '$projects[$i]' SHASUM failed for out_path=$out_path\n"
  return 2
fi
SHA_MAP[$projects[$i]]="$shaval"

# Destination path for the build output <project_name>.tar.gz
# local out_path="$OUT_DIR/$projects[$i].tar.gz"

























# printf "BUILDING BREW DISTRIBUTION:\n"
# printf " - %s\n" $projects

# --------------------------------------------------------------------------------------------
# 2. Define required publish parameters and values
# --------------------------------------------------------------------------------------------
# local ROOT_DIR=/Users/tatehanawalt/Desktop/th_sys # this will change in the future to a dynamically generated absolute path...
local PUSH_REPO_NAME="th_sys"                     # Push release assets: - we can get this from git commands
local init_dir=$(pwd)                             # This will be replaced by the root repository directory

# External dependencies (SPECIFIED BY THE CALLER)
local PUSH_UID=${BUILD_REPO_OWNER}
local AUTH_TOKEN=${BUILD_REPO_TOKEN}
local VERSION=${BUILD_VERSION}

# --------------------------------------------------------------------------------------------



local -A SHA_MAP

# Call the build file for each project with that specific project's parameters (output path, project path, version etc...)

# Call the build script for each project
for ((i=1;i<=${#projects};i++)); do
  local project_root="$ROOT_DIR/$projects[$i]" # Path to specific cli directory
  local build_script="$project_root/bin/build" # Build Script
  local out_path="$OUT_DIR/$projects[$i].tar.gz" # Destination path for the build output <project_name>.tar.gz

  if [ ! -x "$build_script" ]; then
    printf "ERROR: project '$projects[$i]' build script not found at $build_script\n"
    return 2
  fi
  if [ -f "$out_path" ]; then
    printf "ERROR: project '$projects[$i]' out path is an existing file system object\n"
    return 2
  fi

  # --------------------------------------------------------------------------------------------
  # CALL THE PROJECTS BUILD SCRIPT - passes the project name, the out path, and the version
  # --------------------------------------------------------------------------------------------
  $build_script "$project_root" "$out_path" "$VERSION"
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    printf "ERROR: project '$projects[$i]' build script exit_code=$exit_code\n"
    return 2
  fi

  # --------------------------------------------------------------------------------------------
  # DETERMINE THE BUILD SHASUM for the output <out_path>/<project_name>.tar.gz
  # --------------------------------------------------------------------------------------------
  shaval=$(shasum -a 256 $out_path | sed 's/ .*//g')
  if [ $? -ne 0 ]; then
    printf "ERROR: project '$projects[$i]' shaval failed for out_path=$out_path\n"
    return 2
  fi
  if [ -z "$shaval" ]; then
    printf "ERROR: project '$projects[$i]' SHASUM failed for out_path=$out_path\n"
    return 2
  fi
  SHA_MAP[$projects[$i]]="$shaval"

  # --------------------------------------------------------------------------------------------
  # This point indicastes .tar.gz build succeeded for project $projects[$i]
  # --------------------------------------------------------------------------------------------
done


# Completed executing the build script for each project
printf "COMPLETED PACKAGING TAR Archives for Packages:\n"
for project in ${(k)SHA_MAP}; do
  printf "- %-10s - %s\n" $project $SHA_MAP[$project]
done

# --------------------------------------------------------------------------------------------
# Uploads a release asset to the designated parameter group destination
# args: <1:user> <2:repo> <3:tag> <4:git_api_token> <5:file_path>
upload_release_asset() {
  if [ ${#@} -ne 5 ]; then
    printf "ERROR: Argument count != 5... got ARGS=%d\n" ${#@}
    return 1
  fi

  # pre-define method body scoped variables
  local response_code=""
  local request_data=""
  local RELEASE_NUMBER=""

  printf "- USER=%s\n" "$1"
  printf "- REPO=%s\n" "$2"
  printf "- TAG=%s\n" "$3"
  printf "- AUTH_TOKEN_LENGTH=%d\n" ${#4}
  printf "- FILE_PATH=%s\n" ${5}

  # curl -s "https://api.github.com/repos/$1/$2/releases/$3"

  # This checks for the specific release tag
  response_code=$(curl -s --write-out '%{http_code}' --silent --output /dev/null "https://api.github.com/repos/$1/$2/releases/$3")
  if [ ${response_code} -ne 200 ]; then
    printf "ERROR: REPO_CHECK response code != 200... got %s\n" $response_code
    return 2
  fi
  printf "✔ RELEASE_TAG=%s\n" $3

  # This graps the release ID (which is not the tag)
  request_data=$(curl -s "https://api.github.com/repos/$1/$2/releases/$3")
  RELEASE_NUMBER=$(echo $request_data | jq '.id')
  if [ -z "$RELEASE_NUMBER" ]; then
    printf "ERROR: RELEASE_NUMBER failed to get a valid release code... got: %d\n" $RELEASE_NUMBER
    return 2
  fi

  printf "✔ RELEASE_NUMBER=%d\n" $RELEASE_NUMBER

  # This uploads the file to the release
  request_data=$(curl --data-binary @"$5" \
    -H "Authorization: token $4" \
    -H "Content-Type: $(file -b --mime-type $5)" \
    "https://uploads.github.com/repos/$1/$2/releases/$RELEASE_NUMBER/assets?name=$(basename $5)")

  printf "UPLOAD_REQUEST_EXIT_CODE: $?\n"
  printf "REQUEST_DATA:\n"
  printf "%s\n" $request_data
  return 0
}


# This checks that the passed auth api has the correct permissions
local response_code=$(curl -s --write-out '%{http_code}' --silent --output /dev/null -H "Authorization: token $AUTH_TOKEN" "https://api.github.com/repos/$1/$2")
if [ $response_code -ne 200 ]; then
  printf "ERROR: AUTH response code != 200... got %s\n" $response_code
  return 2
fi






# --------------------------------------------------------------------------------------------
# This actually calls the function that uses shell to upload the release asset
result_data="$(upload_release_asset $PUSH_UID $PUSH_REPO_NAME $VERSION $AUTH_TOKEN $TAR_TGT)"
response_code=$?
if [ $response_code -ne 0 ]; then
  printf "UPLOAD_RELEASE_ASSET FAILED with exit code: %d...\n" $response_code
  printf "OUTPUT:\n"
  result_data=(${(@f)"$(echo $result_data)"})
  printf "\t%s\n" $result_data
  return 2
fi

# --------------------------------------------------------------------------------------------
# This point indicates the release asset has been successfully published
#
# return the: shasum, version, asset download url parameters?
printf "UPLOAD_RELEASE_ASSET Completed successfully...\n"
printf "%s\n" "$result_data"
printf "TGT_SHASUM=%s\n" "$TGT_SHASUM"
# --------------------------------------------------------------------------------------------






# return 0
# printf "✔ PERMISSIONS_USER=%s\n" $1
# printf "✔ PERMISSIONS_REPO=%s\n" $2

# This script is used to generate the distribution packages for all the projects
# in the th_sys repository
# Projects in the th_sys repo are distributed in .tar.gz archive format
# The archive for a project is generaged by invoking the <project>/bin/build script
#Each package in the project is responsible for generating
#          archive for distributioin.
#          This script is responsible for invoking the buildi script for each project
#          but this script does not do any compilation or any other type of packaging
#          This script facilitates the bulid process for each project by:
#          - cleaning previously generated builid if they exist
#          - determing the path the project builds the

# packaging scripts are called with arguments:
# 1. The full path to the project.
# 2. A build output directory
# 3. A build version
#
# The build version is expected to beintegrated in the packaged assets in some way.
#
# If packaging is successful the project packaging script places the archive
# in the build output director witht he name "<project_name>.tar.gz"
#
