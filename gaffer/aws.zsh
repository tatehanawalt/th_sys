#!/bin/zsh

source $(dirname $0:A)/config.zsh
debug_aws_script=1

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
    echo
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
  echo
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
  echo
}

# tag="semver=$SEMVER&epoch=$EPOCH&repo=$GIT_REPO&branch=$GIT_BRANCH&commit=$COMMIT&checksum=$CHECKSUM"
# OP=$(aws s3api put-object --key $push_name --bucket $bucket_name --body $push_path --tagging $tag --no-cli-pager )
# echo " taglen: ${#tags}"
