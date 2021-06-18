#!/bin/zsh

COREBUCKET=alexandria-bucket
CORESTACK=root-stack
SEMVER=0.0.0
EPOCH=$(date +'%s')
GIT_ROOT=$(get_git_root)
GIT_REPO=$(get_get_repo)
GIT_BRANCH=$(get_git_branch)
COMMIT=$(get_get_commit)
PREFIX=${PREFIX:=""}
INDENT=${INDENT:="  "}

# Simple helper print method
function title() {
  local SRCDIR=$1
  local OUTDIR=$2
  local CMD=$3
  echo "${PREFIX}${INDENT}SEMVER: $SEMVER"
  echo "${PREFIX}${INDENT}$LINESEP1"
  echo "${PREFIX}${INDENT}$CMD:"
  echo "${PREFIX}${INDENT}SRCDIR: $SRCDIR"
  echo "${PREFIX}${INDENT}OUTDIR: $OUTDIR"
}

# Build project objects
function build_target() {
  local SRCDIR=$1
  local OUTDIR=$2
  title $SRCDIR $OUTDIR BUILD
  echo
  local stackdomain=$CORESTACK
  local bucketdomain=$COREBUCKET
  # root bucket
  create_bucket $bucketdomain
  echo
  # Build all objects (lambdas, tempates... anything) to $OUTDIR
  build_src $SRCDIR $OUTDIR
  # Push all our out resources to the central deploy bucket
  push_out $bucketdomain $OUTDIR
  # Exit if stack exists
  OP=$(set_contains $stackdomain $(list_stacks))
  if [ $? -eq 0 ]; then
    echo "${PREFIX}${INDENT}DETECTED EXISTING STACK $stackdomain"
    return 1
  fi
  echo "${PREFIX}${INDENT}CREATING STACK $stackdomain"
  local deployurl="https://$bucketdomain.s3.amazonaws.com/root.yml"
  echo "${PREFIX}${INDENT}DEPLOYURL: $bucketdomain"
  echo
  # STACK TAGS:
  tags="SEMVER=$SEMVER&OP=gaffer"
  OP=$(aws cloudformation create-stack --stack-name $stackdomain --template-url $deployurl --no-cli-pager --capabilities CAPABILITY_IAM )
  OP=$(echo $OP | grep \"StackId\")
  OP=${OP: :-1}
  OP=${OP##*\"}
  echo "${PREFIX}${INDENT}CORESTACK ARN:"
  echo
  echo "${PREFIX}${INDENT}$OP"
  echo
  return 0
}

# Clean the root project
function clean_target() {
  local SRCDIR=$1
  local OUTDIR=$2

  title $SRCDIR $OUTDIR CLEAN

  local rmd=$OUTDIR
  local rmcount=0

  echo "rmd: ${rmd}"

  if [ ! -d $rmd ]; then
    echo "out directory not found at path=${rmd}"
    return 0
  fi

  echo "${PREFIX}${INDENT}CLEAN BUILD FILES:"

  # Remove files from the build dir
  while IFS= read -r rmf ; do
    [ -z $rmf ] && continue
    echo "${PREFIX}${INDENT}- ${rmf##${rmd}/}"
    rm $rmf
  done <<< $(find $OUTDIR -mindepth 1 -type f)

  [ $rmcount -ne 0 ] && echo
  echo "${PREFIX}${INDENT}CLEAN BUILD DIRS:"

  # Remove files from the build dir
  while IFS= read -r rmf ; do
    [ -z $rmf ] && continue
    echo "${PREFIX}${INDENT}- ${rmf##${rmd}/}"
    rm -r $rmf
  done <<< $(find $OUTDIR -mindepth 1 -type d)
  echo
  return 0
}

# Prints general info about the setup / context
function info_target() {
  local SRCDIR=$1
  local OUTDIR=$2
  title $SRCDIR $OUTDIR INFO
  echo "${PREFIX}${INDENT}$LINESEP1"
  echo "${INDENT}CORE:"
  echo "${PREFIX}${INDENT}COREBUCKET: $COREBUCKET"
  echo "${PREFIX}${INDENT}CORESTACK:  $CORESTACK"
  echo "${PREFIX}${INDENT}$LINESEP1"
  echo "${PREFIX}${INDENT}GIT"
  echo "${PREFIX}${INDENT}REPO:   $GIT_REPO"
  echo "${PREFIX}${INDENT}PATH:   $GIT_ROOT"
  echo "${PREFIX}${INDENT}BRANCH: $GIT_BRANCH"
  echo "${PREFIX}${INDENT}COMMIT: $COMMIT"
  return 0
}

function nix_target() {
  title $1 $2 NIX
  stacks=( $(list_stacks) )
  for i in $stacks; do
    [ -z $i ] && continue
    echo "${PREFIX}${INDENT}DELETE STACK: $i"
    aws cloudformation delete-stack --stack-name $i --no-cli-pager
  done
}

# This is the atomic bomb of resource deletion relative to typical cloud formation
# teardowns...
function purge_target() {
  echo "\n PURGE\n\n"
  buckets=( $(list_buckets) )
  for i in $buckets; do
    echo " bi: $i"
    list_objects $i
  done
  #   echo "\n BUCKETS:\n"
  # echo $buckets



}
