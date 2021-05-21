#!/usr/bin/env zsh
#==============================================================================
# title   :publish.zsh
# version :0.0.0
# desc    :Publish distribution packages to a github release
# auth    :Tate Hanawalt(tate@tatehanawalt.com)
# date    :1621476898
#==============================================================================
# usage   :See below header
# exit    :0=success, 1=input error 2=execution error
#==============================================================================

# Check that the build script was called with the build version
if [ ${#@} -ne 3 ]; then
  printf "ERROR - th_sys/bin/publish.zsh incorrect arguments count. expects \$1=BUILD_OUT_PATH \$2=GITHUB_AUTH_TOKEN \$3=PUBLISH_VERSION Got ${#@} Arguments\n"
  return 1
fi

# jq is a tool used to parse json strings from a shell/command line. We use it frequently
# in the publishing logic
JQ_PATH="$(which jq)"
if [ -z "$JQ_PATH" ]; then
  printf "ERROR - jq tool not found in current environment. check that jq is installed\n"
  return 2
fi

# This is the directory path we expect the published archive files to exist in
BUILD_OUT_PATH=$1
if [ ! -d "$BUILD_OUT_PATH" ]; then
  printf "ERROR - th_sys publish argument 1 is not a directory. Expects \$1=BUILD_OUT_PATH\n"
  return 1
fi

# This is your account authorization token
GITHUB_AUTH_TOKEN=$2
if [ -z "$GITHUB_AUTH_TOKEN" ]; then
  printf "ERROR - th_sys publish argument 2 length is 0. Expects \$2=GITHUB_AUTH_TOKEN\n"
  return 1
fi

# This is your account authorization token
PUBLISH_VERSION=$3
if [ -z "$PUBLISH_VERSION" ]; then
  printf "ERROR - th_sys publish argument 3 length is 0. Expects \$3=PUBLISH_VERSION\n"
  return 1
fi

# Path to the repository
REPOSITORY_ROOT_PATH=$(git rev-parse --show-toplevel 2>&1)
if [ $? -ne 0 ]; then
  printf "ERROR - publish.zsh executed in no git repository\n"
  return 1
fi
if [ ! -d "$REPOSITORY_ROOT_PATH" ]; then
  printf "ERROR - th_sys publish.zsh git rev-parse return non directory path=$REPOSITORY_ROOT_PATH\n"
  return 1
fi

GIT_REMOTE=$(git config --get remote.origin.url)
if [ -z "$GIT_REMOTE" ]; then
  printf "ERROR - th_sys publish.zsh failed to get GIT_REMOTE from \$: git config --get remote.origin.url\n"
  return 1
fi

# Get the name of the repository
REPOSITORY_NAME=$(basename -s .git $GIT_REMOTE)
if [[ "$REPOSITORY_NAME" != "th_sys" ]]; then
  printf "ERROR - th_sys publish.zsh must be executed in the th_sys repository\n"
  return 1
fi

# Get the org of the repository
GIT_REPO_ORG=$(basename $(dirname $GIT_REMOTE) | sed 's/.*://')
if [ -z "$GIT_REPO_ORG" ]; then
  printf "ERROR - th_sys publish.zsh failed to get REPO ORG from \$REPOSITORY_ROOT_PATH=%s\n" "$REPOSITORY_ROOT_PATH"
  return 1
fi

# DO NOT DELETE - Useful for debugging
# printf "PUBLISH:\n"
# printf " - PUBLISH_VERSION=%s\n"          "$PUBLISH_VERSION"
# printf " - BUILD_OUT_PATH=%s\n"           "$BUILD_OUT_PATH"
# printf " - GITHUB_AUTH_TOKEN_LENGTH=%d\n" ${#GITHUB_AUTH_TOKEN}
# printf " - REPOSITORY_ROOT_PATH=%s\n"     "$REPOSITORY_ROOT_PATH"
# printf " - GIT_REMOTE=%s\n"               "$GIT_REMOTE"
# printf " - REPOSITORY_NAME=%s\n"          "$REPOSITORY_NAME"
# printf " - GIT_REPO_ORG=%s\n"             "$GIT_REPO_ORG"
# printf " - JQ_PATH=%s\n"                  "$JQ_PATH"

# Get the set of archive files in the specified path
PUBLISH_ARCHIVES=( ${(@f)"$(find $BUILD_OUT_PATH -type f -maxdepth 1 | grep '.*\.tar.gz$')"} )
if [ ${#PUBLISH_ARCHIVES} -lt 1 ]; then
  printf "ERROR - th_sys publish.zsh BUILD_OUT_PATH does not contain any .tar.gz archives\n"
  return 0
fi

# Set of maps used to store <PROJECT_NAME>=<various values>
declare -A PATH_MAP # PATH_MAP will contain <PROJECT_NAME>=<project archive path>
declare -A SHA_MAP  # SHA_MAP will contain <PROJECT_NAME>=<SHA 256 SUM of project archive path>
declare -A URL_MAP  # Will contain <PROJECT_NAME>=<DOWNLOAD_URL - IF the archive was uploaded only>

# Iterate through the archives (full paths stored in the PUBLISH_ARCHIVES array) and store
# the values required to publish the archives
for ARCHIVE_PATH in $PUBLISH_ARCHIVES; do
  if [ ! -f "$ARCHIVE_PATH" ]; then
    printf "ERROR: PUBLISH_ARCHIVES contains non file PATH=%s\n" "$ARCHIVE_PATH"
    return 2
  fi
  PROJECT_NAME=$(echo $(basename $ARCHIVE_PATH) | sed 's/\..*//')
  if [ -z "$PROJECT_NAME" ]; then
    printf "ERROR: Failed to get project name from ARCHIVE_PATH=%s\n" "$ARCHIVE_PATH"
    return 2
  fi
  SHA_256_SUM=$(shasum -a 256 "$ARCHIVE_PATH" | sed 's/ .*//g')
  if [ $? -ne 0 ]; then
    printf "ERROR: %s SHA_256_SUM failed for ARCHIVE_PATH=%s\n" "$SHA_256_SUM" "$ARCHIVE_PATH"
    return 2
  fi
  if [ -z "$SHA_256_SUM" ]; then
    printf "ERROR: %s SHA_256_SUM failed for ARCHIVE_PATH=%s\n" "$SHA_256_SUM" "$ARCHIVE_PATH"
    return 2
  fi
  PATH_MAP[${PROJECT_NAME}]="$ARCHIVE_PATH"
  SHA_MAP[${PROJECT_NAME}]="$SHA_256_SUM"
  # DO NOT DELETE - Useful for debugging
  # printf "PROJECT\n"
  # printf " - NAME=%s\n" "$PROJECT_NAME"
  # printf " - ARCHIVE_PATH=%s\n" "$ARCHIVE_PATH"
  # printf " - SHA_256_SUM=%s\n" "$SHA_256_SUM"
  # printf "\n"
done

# This section queries the existing set of releases, searches for the release tag we want
# and collects the names of existing release assets

# Get the JSON list of releases
RELEASE_LIST_JSON=$(curl -s https://api.github.com/repos/$GIT_REPO_ORG/$REPOSITORY_NAME/releases)
if [ -z "$RELEASE_LIST_JSON" ]; then
  printf "ERROR - failed to get the list of releases\n" "$PUBLISH_VERSION"
  return 2
fi
# Get the release witht the tag_name matching the specified $PUBLISH_VERSION
RELEASE_JSON_STR=$(echo $RELEASE_LIST_JSON | jq -c ".[] | select(.tag_name | contains(\"$PUBLISH_VERSION\"))" | jq)
if [ -z "$RELEASE_JSON_STR" ]; then
  printf "ERROR: Release with tag_name=%s not found.\n" "$PUBLISH_VERSION"
  return 2
fi
# Search the list of releases for a release with tag_name=$PUBLISH_VERSION
RELEASE_ID=$(echo $RELEASE_JSON_STR | jq '.id')
if [ -z "$RELEASE_ID" ]; then
  printf "ERROR: failed to retrieve the RELEASE_ID\n"
  return 2
fi
# Get the set of existing release assets
RELEASE_ASSETS_JSON_STR=$(echo $RELEASE_JSON_STR | jq '.assets')

# DO NOT DELETE - useful for debugging
# printf "RELEASE_LIST_JSON:\n${RELEASE_LIST_JSON}\n\n"
# printf "RELEASE_JSON_STR:\n${RELEASE_JSON_STR}\n\n"
# printf "RELEASE_ASSETS_JSON_STR:\n${RELEASE_ASSETS_JSON_STR}\n"

# Get the name of each existing release asset (this can absolutely return nothing when a release has no assets)
EXISTING_RELEASE_ASSET_NAMES=( ${(@f)$(echo "$RELEASE_ASSETS_JSON_STR" | jq -r ".[] | .name")} )
printf "\nEXISTING_RELEASE_ASSET_NAMES:\n"
printf "- %s\n" $EXISTING_RELEASE_ASSET_NAMES
printf "\n"

# for existing published projects
PUBLISHED_PROJECTS=()
for RELEASE_ASSET_NAME in $EXISTING_RELEASE_ASSET_NAMES; do
  PUBLISHED_PROJECTS+=("$(echo $RELEASE_ASSET_NAME | sed 's/\..*//')")
done

# for pojects after they successfully upload
NEWLY_PUBLISHED=()
for PROJECT_NAME in ${(k)PATH_MAP}; do
  local published=1
  for PUBLISHED_PROJECT_NAME in $PUBLISHED_PROJECTS; do
    [ "$PUBLISHED_PROJECT_NAME" != "$PROJECT_NAME" ] && continue
    published=0
    break
  done
  if [ $published -eq 0 ]; then
    printf " ✘ %-10s - ALREADY PUBLISHED\n" "$PROJECT_NAME" && continue
    continue
  fi
  PATH_BASE_NAME=$(basename "$PATH_MAP[$PROJECT_NAME]")
  PROJECT_ARCHIVE_PATH="$PATH_MAP[$PROJECT_NAME]"
  if [ ! -f "$PROJECT_ARCHIVE_PATH" ]; then
    printf " ✘ %-10s - ARCHIIVE PATH IS NOT AN EXISTING FILE\n" "$PROJECT_NAME" && continue
    continue
  fi
  REQUEST_DATA=$(curl \
    --data-binary @"$PATH_MAP[$PROJECT_NAME]" \
    -H "Authorization: token $GITHUB_AUTH_TOKEN" \
    -H "Content-Type: $(file -b --mime-type $PROJECT_ARCHIVE_PATH)" \
    "https://uploads.github.com/repos/$GIT_REPO_ORG/$REPOSITORY_NAME/releases/$RELEASE_ID/assets?name=$PATH_BASE_NAME")
  DOWNLOAD_URL=$(echo $REQUEST_DATA | \
    jq '.browser_download_url' | \
    sed 's/^\"//' | \
    sed 's/\"$//')
  if [ -z "$DOWNLOAD_URL" ]; then
    printf "Failed to get the browser download url after publishing $PROJECT_NAME...\n"
    continue
  fi
  # PROJECT IS OFFICIALLY NEWLY UPLOADED TO THE RELEASE
  URL_MAP[$PROJECT_NAME]=$DOWNLOAD_URL
  NEWLY_PUBLISHED+=($PROJECT_NAME)
  printf " ✔ %-10s - PUBLISHED\n" "$PROJECT_NAME"
done

NEWLY_PUBLISHED=(${(@f)$(printf "%s\n" ${(k)URL_MAP} | sort)})
if [ ${#NEWLY_PUBLISHED} -lt 1 ]; then
  printf "No new assets were published... exiting\n"
  return 0
fi

printf "NEWLY_PUBLISHED (CSV):\n"
printf "name,shasum,url\n"
for NEW_PUBLISHED_PROJECT in $NEWLY_PUBLISHED; do
  PROJECT_DOWNLOAD_URL=$URL_MAP[$NEW_PUBLISHED_PROJECT]
  get_download_url_exit_code=$?
  if [ $get_download_url_exit_code -ne 0 ]; then
    printf "ERROR - getAssetBrowserURL failed for $NEW_PUBLISHED_PROJECT with exit code $get_download_url_exit_code\n"
    continue
  fi
  printf "%s,%s,%s\n" "$NEW_PUBLISHED_PROJECT" "$SHA_MAP[$NEW_PUBLISHED_PROJECT]" "$PROJECT_DOWNLOAD_URL"
done

printf "\n"
return 0
