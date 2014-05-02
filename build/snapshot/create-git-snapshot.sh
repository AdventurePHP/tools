#!/bin/bash
##############################################################################
DIR=$(cd $(dirname "$0"); pwd)
WORKSPACE=$DIR/workspace
REL_DIR=$DIR/../files/snapshot
##############################################################################

echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo ":: Generate APF snapshot                                                     ::"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo -n "start at: "
date +"%Y-%m-%d, %H:%M:%S"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo

if [ -z "$1" ] || [ -z "$2" ]; then 
   echo "Not enough parameters. Aborting!"
   echo "Usage: $0 <git-branch> <release-version>"
   echo
   exit 1
fi

# define version related parameters
GIT_BRANCH=$1
REL_VERSION=$2

echo "[INFO] Creating snapshot release for version $REL_VERSION from branch $GIT_BRANCH ..."
echo "[INFO] Using workspace $WORKSPACE to preare snapshot release ..."

# create workspace
if [ ! -d $WORKSPACE ]; then
   mkdir -p $WORKSPACE
fi

cd $WORKSPACE

# clear workspace before export
echo "[INFO] Clearing workspace ..."
rm -rf *

# export code from git
echo "[INFO] Fetching sources from GitHub ..."
git clone --depth 1 --branch $GIT_BRANCH https://github.com/AdventurePHP/code.git . > /dev/null 2>&1
rm -rf .git

# export config from git
echo "[INFO] Fetching sample config from GitHub ..."
mkdir config && cd config
git clone --depth 1 --branch $GIT_BRANCH https://github.com/AdventurePHP/config.git . > /dev/null 2>&1
rm -rf .git

cd ..

# create snapshot file
echo "[INFO] Creating TGZ file ..."
SNAPSHOT_FILE=apf-$REL_VERSION-snapshot-php5.tar.gz
tar -czf ../$SNAPSHOT_FILE * 

# remove existing prior snapshot release file
if [ -f $REL_DIR/$SNAPSHOT_FILE ]; then
   rm -f $REL_DIR/$SNAPSHOT_FILE
fi

# transport to release dir
echo "[INFO] Publishing snapshot file $SNAPSHOT_FILE for version $REL_VERSION from branch $GIT_BRANCH ..."
mv ../$SNAPSHOT_FILE $REL_DIR

echo
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo -n "end at  : "
date +"%Y-%m-%d, %H:%M:%S"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
