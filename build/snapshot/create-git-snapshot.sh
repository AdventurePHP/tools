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
GIT_BRANCH=$1
REL_VERSION=$2

# create workspace
if [ ! -d $WORKSPACE ]; then
   mkdir -p $WORKSPACE
fi

cd $WORKSPACE

# clear workspace before export
rm -rf *

# export code from git
git clone --depth 1 --branch $GIT_BRANCH https://github.com/AdventurePHP/code.git .
rm -rf .git

# export config from git
mkdir config && cd config
git clone --depth 1 --branch $GIT_BRANCH https://github.com/AdventurePHP/config.git .
rm -rf .git

cd ..

# create snapshot file
SNAPSHOT_FILE=apf-$REL_VERSION-snapshot-php5.tar.gz
tar -czf ../$SNAPSHOT_FILE * 

# more snapshot to release dir
if [ -f $REL_DIR/$SNAPSHOT_FILE ]; then
   rm -f $REL_DIR/$SNAPSHOT_FILE
fi

mv ../$SNAPSHOT_FILE $REL_DIR
