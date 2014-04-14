#!/bin/bash
##############################################################################
DIR=$(cd $(dirname "$0"); pwd)
WORKSPACE=$DIR/workspace
REL_DIR=$DIR/../files/snapshot
##############################################################################

if [ -z "$1" ] || [ -z "$2" ]; then 
   echo "Not enough parameters. Aborting!"
   echo "Usage: $0 <git-branch> <release-version>"
   echo
   exit 1
fi

# define version related parameters
GIT_URL=https://github.com/AdventurePHP/code.git

GIT_BRANCH=$1
REL_VERSION=$2

# create workspace
if [ ! -d $WORKSPACE ]; then
   mkdir -p $WORKSPACE
fi

cd $WORKSPACE

# clear workspace before export
rm -rf *

# export from git
git clone --depth 1 --branch $GIT_BRANCH $GIT_URL .
rm -rf .git

# create snapshot file
SNAPSHOT_FILE=apf-$REL_VERSION-snapshot-php5.tar.gz
tar -czf ../$SNAPSHOT_FILE * 

# more snapshot to release dir
TARGET_FILE=$REL_DIR/
if [ -f $REL_DIR/$SNAPSHOT_FILE ]; then
   rm -f $REL_DIR/$SNAPSHOT_FILE
fi

mv ../$SNAPSHOT_FILE $REL_DIR
