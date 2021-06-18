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
