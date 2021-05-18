#!/usr/bin/env zsh

printf "\nBUILDING BREW DISTRIBUTION:\n\n"

# --------------------------------------------------------------------------------------------
# COMMAND: build_brew_dist
# --------------------------------------------------------------------------------------------
# Script variables:
# --------------------------------------------------------------------------------------------
# TODO: Get these from git commands
local ROOT_DIR=/Users/tatehanawalt/Desktop/th_sys # this will change in the future to a dynamically generated absolute path...
local PUSH_REPO_NAME=".th_sys"                    # Push release assets: - we can get this from git commands
local init_dir=$(pwd)                             # This will be replaced by the root repository directory
local projects=(demo1 demo2)                      # this will be generated dynamically

# External dependencies (SPECIFIED BY THE CALLER)
local PUSH_UID=${BUILD_REPO_OWNER}
local AUTH_TOKEN=${BUILD_REPO_TOKEN}
local VERSION="latest"

# --------------------------------------------------------------------------------------------
# Define && Clean the OUT Directory - <repo_path>/out directory
local OUT_DIR="$ROOT_DIR/out"
[ -d "$OUT_DIR" ]  && rm -r "$OUT_DIR"
mkdir "$OUT_DIR"

local -A SHA_MAP

printf "Projects:\n"
printf "- %s\n" $projects
printf "\n"

# Call the build script for each project
for ((i=1;i<=${#projects};i++)); do
  local project_root="$ROOT_DIR/$projects[$i]"
  local build_script="$project_root/bin/build"
  if [ ! -x "$build_script" ]; then
    printf "ERROR: project '$projects[$i]' build script not found at $build_script\n"
    return 2
  fi
  local out_path="$OUT_DIR/$projects[$i].tar.gz"
  if [ -f "$out_path" ]; then
    printf "ERROR: project '$projects[$i]' out path is an existing file system object\n"
    return 2
  fi
  $build_script "$project_root" "$out_path" "$VERSION"
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    printf "ERROR: project '$projects[$i]' build script exit_code != 0... got exit_code=$d\n" $exit_code
    return 2
  fi
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
  printf "\n"
done

for project in ${(k)SHA_MAP}; do
  printf "PUSH_RELEASE_ASSET:\n"
  printf "- PROJECT:   %s\n" $project
  printf "- BUILD_SHA: %s\n" $SHA_MAP[$project]
  printf "\n"
done

return 0





# printf "SHA_MAP:\n"
# printf "\t%s\n" $SHA_MAP
# printf "\n"
# return 0

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

  # This checks that the passed auth api has the correct permissions
  response_code=$(curl -s --write-out '%{http_code}' --silent --output /dev/null -H "Authorization: token $4" "https://api.github.com/repos/$1/$2")
  if [ $response_code -ne 200 ]; then
    printf "ERROR: AUTH response code != 200... got %s\n" $response_code
    return 2
  fi
  printf "✔ PERMISSIONS_USER=%s\n" $1
  printf "✔ PERMISSIONS_REPO=%s\n" $2

  curl -s "https://api.github.com/repos/$1/$2/releases/$3"

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
printf "UPLOAD_RELEASE_ASSET Completed successfully...\n\n"
printf "\n%s\n" "$result_data"
printf "TGT_SHASUM=%s\n" "$TGT_SHASUM"
# --------------------------------------------------------------------------------------------



# This is <the snippet>

# local TAR_SRC="$ROOT_DIR/$P_NAME"
# local TAR_TGT="$OUT_DIR/$P_NAME.tar.gz"
# local P_NAME=demo1
#
# # --------------------------------------------------------------------------------------------
# # This script builds the release artifact tar file for brew installation publishing
# printf "BUILDING:\n"
# printf "- PROJECT=%s\n" ${P_NAME}
# printf "- REPO=%s\n" ${PUSH_REPO_NAME}
# printf "- PUSH_UID=%s\n" "$PUSH_UID"
# printf "- VERSION=%s\n" "$VERSION"
# printf "- ROOT_DIR=%s\n" "$ROOT_DIR"
# printf "- OUT_DIR=%s\n" "$OUT_DIR"
# printf "- TAR_SRC=%s\n" "$TAR_SRC"
# printf "- TAR_TGT=%s\n" "$TAR_TGT"
#
# # --------------------------------------------------------------------------------------------
# # Clean the <repo_path>/out directory
# [ -d "$OUT_DIR" ]  && rm -r "$OUT_DIR"
# mkdir "$OUT_DIR"
# cd "$TAR_SRC"
# local files_set=(${(@)$(ls)})
# printf "- FS_ITEMS:\n"
# printf "  • %s\n" $files_set
# printf "- FS_ITEMS_COUNT=%d\n" ${#files_set}
#
# # --------------------------------------------------------------------------------------------
# # Tar the source files
# tar -czf "$TAR_TGT" .
# if [ ! -f "$TAR_TGT" ]; then
#   printf "ERROR: tar failed for source=%s, target=%s\n" "$TAR_SRC" "$TAR_TGT"
#   return 2
# fi


# # Capture the shaval for the project
# SHA_MAP[$projects[$i]]=$(shasum -a 256 $out_path | sed 's/ .*//g')
# if [ -z "$TGT_SHASUM" ]; then
#   printf "ERROR: project '$projects[$i]' SHASUM failed for out_path=$out_path\n"
#   return 2
# fi



# <here is where the snippet went>
# --------------------------------------------------------------------------------------------
# Get the shasum of the tarfile
# local TGT_SHASUM="$(shasum -a 256 $TAR_TGT | sed 's/ .*//g')"
# if [ -z "$TGT_SHASUM" ]; then
#   printf "ERROR: SHASUM failed for TAR_TARGET=%s\n" ${TAR_TGT}
#   return 2
# fi
