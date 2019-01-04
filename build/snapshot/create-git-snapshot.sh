#!/bin/bash
# define git url
GIT_URL_CODE=https://github.com/AdventurePHP/code.git
GIT_URL_CONFIG=https://github.com/AdventurePHP/config.git

# functions

####################################################################################################
# usage function
function usage() {
   echo "Usage: ./$0 <git-branch> <release-version>"
}

####################################################################################################
# footer function
function displayFooter() {
   echo
   echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
   echo -n "end at  : "
   date +"%Y-%m-%d, %H:%M:%S"
   echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
}
####################################################################################################

# preflight checks
if [ -z "$1" ] || [ -z "$2" ]; then 
   echo "Error: Not enough parameters. Exiting!"
   usage
   exit 1
fi

DEPS="git tar"
which $DEPS  > /dev/null 2>&1
if [ "$?" -ne 0 ]; then
    echo "Error: Missing one or more dependencies. Exiting."
    echo "Dependencies: $DEPS"
    exit 1
fi

# define version related parameters
GIT_BRANCH=$1
REL_VERSION=$2

##############################################################################
WDIR=${0%/*}
WORKSPACE=$(mktemp -d) && trap "rm -rf $WORKSPACE ; displayFooter" EXIT
REL_DIR=$WDIR/../files/snapshot
##############################################################################

echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo ":: Generate APF snapshot                                                     ::"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo -n "start at: "
date +"%Y-%m-%d, %H:%M:%S"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo

echo "[INFO] Creating snapshot release for version $REL_VERSION from branch $GIT_BRANCH ..."
echo "[INFO] Using workspace $WORKSPACE to prepare snapshot release ..."

# export code from git
echo "[INFO] Fetching sources from GitHub ..."
git clone --depth 1 --branch $GIT_BRANCH $GIT_URL_CODE $WORKSPACE/build

if ! [ "$?" -eq 0 ]; then
    echo "Error: Could not clone git repo. Exiting."
    exit 1
fi

[ -d $WORKSPACE/build/.git ] && rm -rf $WORKSPACE/build/.git

# export config from git
echo "[INFO] Fetching sample config from GitHub ..."
[ -d $WORKSPACE/build/config ] || mkdir $WORKSPACE/build/config
git clone --depth 1 --branch $GIT_BRANCH $GIT_URL_CONFIG $WORKSPACE/build/config

if ! [ "$?" -eq 0 ]; then
    echo "Error: Could not clone git repo. Exiting."
    exit 1
fi

[ -d  $WORKSPACE/build/config/.git ] && rm -rf $WORKSPACE/build/config/.git

# create snapshot file
echo "[INFO] Creating tar.gz file ..."
SNAPSHOT_FILE=apf-$REL_VERSION-snapshot-php7.tar.gz
cd $WORKSPACE/build
tar -cz --exclude=.travis.yml --exclude=composer.json --exclude=tests -f $WORKSPACE/$SNAPSHOT_FILE *
cd -

if ! [ "$?" -eq 0 ]; then
    echo "Error: Could no compress snapshot release. Exiting."
    exit 1
fi

# transport to release dir
echo "[INFO] Publishing snapshot file $SNAPSHOT_FILE for version $REL_VERSION from branch $GIT_BRANCH ..."
[ -d $REL_DIR ] || mkdir -p $REL_DIR
mv -f $WORKSPACE/$SNAPSHOT_FILE $REL_DIR

exit 0
