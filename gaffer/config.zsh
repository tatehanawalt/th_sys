#!/bin/zsh

# Used to define example variables
# Root Dir
VERBOSE=1
PIPCMD=pip3

# PIPLIBS python packages for our lambda
PIPLIBS=()
# PIPLIBS+=(urllib3)
# PIPLIBS+=(crhelper)

# Root project path
OUTDIR=out
ROOTDIR=$(pwd)

# Target Directories
OUTPATH=$ROOTDIR/$OUTDIR
LAMBDASRCPATH=$ROOTDIR/$LAMBDASRC

# STACK
STACKNAME=serverstack
STACKTEMPLATE=$STACKNAME.yml

# LAMBDA
# VARDEFS
LAMBDANAME=rscfn
LAMBDACODEFILE=$LAMBDANAME.py
LAMBDAHANDLER=customrschandler
LAMBDASRC=src
LAMBDAZIP=$LAMBDANAME.zip
# Full path of dir we build the lambda zip to
LAMBDAZIPPATH=$OUTPATH/$LAMBDAZIP

# Build a layer
LAYERNAME=layer
LAYERSRC=src2
LAYERZIP=$LAYERNAME.zip
LAYERZIPPATH=$OUTPATH/$LAYERZIP

# ROOT BUCKET
ROOTBUCKETNAME=deploy-src

debug_aws_script=1

LINESEP1="---------------------------------------------------------------------------------"
LINESEP0="--$LINESEP1"
PREFIX=${PREFIX:=""}
INDENT=${INDENT:="  "}

# Priint method
function shortlbl() {
  echo "${PREFIX}${INDENT}* $1:"
  echo "${PREFIX}${INDENT}${INDENT}$2\n"
}
function set_contains() {
  match=$1
  shift
  for i do
    [[ $i == $match ]] && return 0;
  done
  return 1
}

# HELPERS:
function rmdir() {
  TARGET="$1"
  # shortlbl "REMOVE DIR" ${TARGET}
  [ -z $TARGET ] && return 1
  [ ! -d $TARGET ] && return 1
  rm -r ${TARGET}
  return 0
}
function chk_mkdir() {
  [ -d $1 ] && return 0
  [ -f $1 ] && return 1
  [ ! -d $1 ] && mkdir $1
  [ -d $1 ] && return 0
  return 1
}
function rmfile() {
  TARGET=$1
  [ -z $TARGET ] && return 1
  [ ! -f $TARGET ] && return 1
  rm ${TARGET}
  return 0
}
function changedir() {
  TARGET=$1
  [ ! -d ${TARGET} ] && return 1
  cd ${TARGET}
  return 0
}
function zipcwdto() {
  TARGET=$1
  OP=$(zip -r $TARGET ./* .*)
  [ $VERBOSE -ne 0 ] && return
  for ln (${(f)OP}); do
    cln=$(echo $ln | cut -d" "  -f4-)
    echo "${PREFIX}${INDENT}+ $cln"
  done
}
function gettmpdir() {
  TMPDIR=$(mktemp -d)
  OP=$?
  [ ! -d $TMPDIR ] && return 1
  [ $OP -ne 0 ] && return 2
  echo $TMPDIR
  return 0
}
# changedir $TMPDIR
function changetmpdir() {
  # return 1
  TMPDIR=$(gettmpdir)
  #  OP=$?
  #  [ $OP -ne 0 ] && return 1
  #  changedir $TMPDIR
  #  echo $TMPDIR
  return 0
}
function cp_from() {
  CPFOM=$1
  # shortlbl "CP FROM" "${CPFOM}"
  [ -d $CPSRC ] && cp -r $CPFOM/* .
}
function libs_sha() {
  IFS=$'\n' sorted=($(sort <<<"${PIPLIBS[*]}"))
  unset IFS
  SHASUM=$(echo -n "${sorted[*]}" | shasum -a 256)
  print $SHASUM | grep -o '^\S*'
}

is_git_dir() { [ $# -gt 0 ] && [ ! -z $1 ] && [ -d $1/.git ] }
get_git_root() {
  local root=$(git rev-parse --show-toplevel 2>&1)
  [ ! -d $root/.git ] && return 1
  is_git_dir $root
  [ $? -ne 0 ] && return 1
  echo $root
  return 0
}
get_git_branch() {
  local root=$(get_git_root)
  [ $? -ne 0 ] && return 1
  echo $(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
  return 0
}
get_get_repo() {
  local root=$(get_git_root)
  repo=$(cd $root; git config --get remote.origin.url)
  repo=${repo##*/}
  repo=${repo%%\.git*}
  echo $repo
}
get_get_commit() {
  local commit=$(git rev-parse --verify HEAD)
  echo $commit
}

function build_lambda() {
  local origin=$(pwd)
  local src=$1
  local name=$2
  local out=$3
  local archiveDst=$out/$name.zip

  # Make/cd to tmp diir
  zipdir=$(gettmpdir)
  [ $? -ne 0 ] && echo "failed changetmpdir" && return 1

  local srctype=LAMBDA
  local runtime=NOTSET
  local handler=NOTSET

  echo "${PREFIX}${INDENT}$src"

  # GO Lambda Builder:
  if [ -f $src/lambda_function.go ]; then
    echo "${PREFIX}${INDENT}DETECTED GO"
    local prego=$(pwd)
    cd $src
    GOOS=linux go build -o $zipdir/handler
    cd $prego
    runtime=go1.x
    handler=handler
  fi

  # We move to the zipdir after the go builder because we don't want to copy anything
  cd $zipdir

  # NodeJS Lambda Builder:
  if [ -f $src/lambda_function.js ]; then
    echo "${PREFIX}${INDENT}DETECTED NODE"
    cp_from $src
    # need to run npm install?
    runtime=nodejs14.x
    handler=lambda_function.handler
  fi

  # Python Lambda Builder:
  if [ -f $src/lambda_function.py ]; then
    echo "${PREFIX}${INDENT}DETECTED PYTHON"
    cp_from $src
    # need to run pip?
    runtime=nodejs14.x
    handler=lambda_function.handler
  fi

  # At this point we probably ran copy everything src->dst
  # .depshellmeta is a meta file which is not part of the checksum
  [ -f $zipdir/.depshellmeta ] && rm $zipdir/.depshellmeta
  buildsum=( $(find $zipdir -type f | sort -u | xargs cat | shasum -a 256 | xargs) )

  # Now we write the .depshellmeta file to the content space
  echo -e "CHECKSUM=$buildsum[1]" >> $zipdir/.depshellmeta
  echo -e "TYPE=$srctype" >> $zipdir/.depshellmeta
  echo -e "RUNTIME=$runtime" >> $zipdir/.depshellmeta
  echo -e "HANDLER=$handler" >> $zipdir/.depshellmeta
  echo -e "EPOCH=$EPOCH" >> $zipdir/.depshellmeta
  echo -e "SEMVER=$SEMVER" >> $zipdir/.depshellmeta
  echo -e "REPO=$GIT_REPO" >> $zipdir/.depshellmeta
  echo -e "BRANCH=$GIT_BRANCH" >> $zipdir/.depshellmeta

  # Zip cwd to arg1
  zipcwdto $archiveDst

  # Return to the origin
  cd $origin

  # Remove a previous zip if one exists
  rmdir $zipdir

  echo
  return

  # cd $zipdir
  # find $zipdir -type f | sort -u | xargs cat | shasum -a 256 | xarg
  #  # pip inistall
  #  if [ ${#PIPLIBS[@]} -gt 0 ]; then
  #    echo "\n BUIDING PIP LIBS: " $PIPLIBS
  #    OP=$($PIPCMD install -t . ${PIPLIBS[*]} 2>&1)
  #    if [ $VERBOSE -eq 0 ]; then
  #      for ln (${(f)OP}); do
  #        printf "\t$ln\n"
  #      done
  #      echo
  #    fi
  #  fi
  #}
}

function list_objects() {
  echo "list_objects temporary leaving this..."
  aws s3api list-objects --bucket $1 --no-cli-pager --query 'Contents[*].Key'
}

function list_buckets() {
  buckets=()
  aws s3api list-buckets --no-cli-pager | grep \"Name\" | while read -r NAME; do
    NAME=${NAME: :-2} # Remove last two characters
    NAME=${NAME##*\"}
    buckets+=($NAME)
  done
  echo $buckets
}

function create_bucket() {
  $(set_contains $1 $(list_buckets))
  if [ $? -ne 0 ]; then
    echo "${PREFIX}${INDENT}CREATING $1"
    OP=$(aws s3api create-bucket --bucket $1 --no-cli-pager )
    [ $? -ne 0 ] && return 1
    # return $?
  else
    echo "${PREFIX}${INDENT}DETECTED $1"
  fi
  OP=$(aws s3api put-bucket-versioning --bucket $1 --versioning-configuration Status=Enabled --no-cli-pager)
  echo "${PREFIX}${INDENT}Enabled Versioning: $?"
}

function list_stacks() {
  STACKS=()
  aws cloudformation describe-stacks | grep \"StackName\" | while read -r NAME; do
    NAME=${NAME: :-2}
    NAME=${NAME##*\"}
    STACKS+=($NAME)
  done
  echo $STACKS
}

function build_src() {
  local SRCDIR=$1
  local OUTDIR=$2

  # Copy Static Files:
  chk_mkdir $OUTDIR
  while IFS= read -r src ; do
    cp $src $OUTDIR
  done <<< $(find $SRCDIR/templates -maxdepth 1 -mindepth 1 -type f)

  # Build the lambda functions:
  chk_mkdir $OUTDIR/lambda
  while IFS= read -r src ; do
    build_lambda $src $(basename $src) $OUTDIR/lambda
  done <<< $(find $SRCDIR/lambda -maxdepth 1 -mindepth 1 -type d)

  return 0
}

# $push_bucket $push_name $push_path
function push_path_to_bucket() {
  local bucket_name=$1
  local push_name=$2
  local push_path=$3
  local tags=$4

  if [ $debug_aws_script -eq 0 ]; then
    echo "${PREFIX}${INDENT}$LINESEP1"
    echo "${PREFIX}${INDENT}PUSH BUCKET"
    echo "${PREFIX}${INDENT}${INDENT}NAME: $push_name"
    echo "${PREFIX}${INDENT}${INDENT}FILE: $bucket_name"
    echo "${PREFIX}${INDENT}${INDENT}SRC:  $push_path"
  fi

  [ -z $bucket_name ] && return 1
  [ -z $push_name ] && return 2
  [ -z $push_path ] && return 3
  [ ! -f $push_path ] && return 4

  local CHECKSUM="NOSET"

  # Gete the extension o fthe file
  push_ext=$push_path:t:e

  case $push_ext in
    zip)
      # unzip -l $push_path # can be good for debugging
      # CHECKSUM=$(unzip -p $push_path .checksum)
      # dshellmeta=$(unzip -p $push_path .depshellmeta)
      # echo "\n\n${dshellmeta}\n\n"
      ;;
      *)
      ;;
  esac

  if [ ${#tags} -gt 0 ]; then
    OP=$(aws s3api put-object --key $push_name --bucket $bucket_name --body $push_path --tagging $tags --no-cli-pager)
  else
    OP=$(aws s3api put-object --key $push_name --bucket $bucket_name --body $push_path --no-cli-pager )
  fi
}

# Push the contents of a build out directory to the specified lambda
function push_out() {
  # local BUCKET=$1
  # local DEPLOYSRC=$2

  # Publish the src bucket files
  # ==============================================================================
  echo "${PREFIX}${INDENT}$LINESEP1"
  echo "${PREFIX}${INDENT}PUSH BUCKET $1:"
  while IFS= read -r src ; do
    [ -z $src ] && continue
    name=$(basename $src)
    rel=${src#$2/}
    parts=($(echo ${rel//\// }))
    div="noop"
    # tags="COMMIT=${COMMIT}"
    tags=""
    [ ${#parts[@]} -eq 2 ] && div=${parts[1]}
    case ${div} in
      noop)
        echo "${PREFIX}${INDENT}${INDENT}noop:   $name"
        tags="OP=gaffer"
        tags="COMMIT=${COMMIT}&tags"
        local checksumset=( $(shasum -a 256 $src | xargs) )
        tags="BRANCH=${GIT_BRANCH}&$tags"
        tags="CHECKSUM=${checksumset[1]}&$tags"
        tags="EPOCH=${EPOCH}&$tags"
        tags="SEMVER=${SEMVER}&$tags"
        tags="TYPE=NOOP&$tags"
        tags="REPO=${GIT_REPO}&$tags"
        ;;
      lambda)
        echo "${PREFIX}${INDENT}${INDENT}lambda: $name"
        tags="OP=gaffer"
        tags="COMMIT=${COMMIT}&tags"
        dshellmeta=$(unzip -p $src .depshellmeta)
        while IFS= read -r line ; do
          arr=( $(echo ${line//=/ }) )
          tags="$tags&${arr[1]}=${arr[2]}"
        done <<< "$dshellmeta"
        ;;
        *)
        echo "${PREFIX}${INDENT}${INDENT}NOT FOUND: $name"
    esac
    push_path_to_bucket $1 $name $src ${tags}
  done <<< $(find $2 -maxdepth 2 -mindepth 1 -type f)
}

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
