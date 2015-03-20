#!/bin/bash
####################################################################################################
#
# Build script for the APF release files (PHP5).
#
# @author Christian Achatz
# @version
# Version 0.1, 29.06.2008
# Version 0.2, 04.09.2010 (PHP4 cleanup + fix for file permissions)
# Version 0.3, 24.02.2011 (Added example pack generation, fixed code base generation)
# Version 0.4, 05.09.2013 (Adapted to new notebook)
# Version 0.5, 25.01.2014 (Introduced generic params to allow build on different environments)
#
####################################################################################################

echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo ":: Generate APF release                                                      ::"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo -n "start at: "
date +"%Y-%m-%d, %H:%M:%S"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo

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
# process params
CONF=
GIT_BRANCH=
BUILDVERS=
MODULES=all
USAGE=0
while getopts "b:v:c:m:h" option
do
  case $option in
    c) CONF=$OPTARG;;
    b) GIT_BRANCH=$OPTARG;;
    v) BUILDVERS=$OPTARG;;
    m) MODULES=$OPTARG;;
    h) USAGE=1
  esac
done
shift $(($OPTIND - 1))

# check params
if [ -z "$CONF" ] || [ -z "$GIT_BRANCH" ] || [ -z "$BUILDVERS" ] || [ -z "$MODULES" ] || [ "$USAGE" == "1" ]
then
   # displax error in case of issues with the call
   if [ "$USAGE" == "0" ]
   then
      echo "[ERROR] Not enough arguments!"
   fi

   echo "Usage: $(basename $0) -c <config-file> -b <git branch> -v <build-version> [-m <modules-to-build>]"
   echo
   echo "Please note: <git branch> must be replaced with the name of the GIT branch and <build-version> indicates the version number in the release files."
   echo "Using the -o parameter you can create a build with the sources downloaded beforehand."
   echo "The configuration file referred to must specify the following parameters:"
   echo
   echo "- CODE_LOCAL_REPO_PATH (opt)   : The source location where the APF sources are checked out on local disk."
   echo "- DOCS_LOCAL_REPO_PATH (opt)   : The source location where the APF documentation page is checked out on local disk."
   echo "- CONFIG_LOCAL_REPO_PATH (opt) : The source location where the APF sample config is checked out on local disk."
   echo "- EXAMPLE_LOCAL_REPO_PATH (opt): The source location where the APF examples are checked out on local disk."
   echo "- BUILD_PATH                   : The path where the build is created and stored."
   echo
   echo "In case the configuration defines \"DOCS_LOCAL_REPO_PATH\" and/or \"CODE_LOCAL_REPO_PATH\" and/or \"CONFIG_LOCAL_REPO_PATH\" and/or \"EXAMPLE_LOCAL_REPO_PATH\" the build script tries to use a local clone of the APF repo(s)."
   echo
   echo "The list of modules (-m) can either be \"all\" (default) or a comma-separated list of the following items (or just one):"
   echo
   echo "- apidocs   : APF doxygen documentation."
   echo "- codepack  : Code release files."
   echo "- configpack: Sample configuration files."
   echo "- demopack  : Sandbox release files."
   echo "- examples  : Implementation examples (vbc, modules, calc)."

   # display footer, since we end here...
   displayFooter

   # state correct exit code...
   if [ "$USAGE" == "1" ]
   then
      exit 0
   else
      exit 1
   fi
fi

# gather current directory
DIR=$(cd $(dirname "$0"); pwd)

####################################################################################################
# check enabled modules
function isModuleEnabled() {
   echo $(echo $MODULES | grep -c "$1")
}

ALL_ENABLED=$(isModuleEnabled "all")
if [ "$ALL_ENABLED" == "1" ]
then
   DOCS_ENABLED=1
   CODE_ENABLED=1
   CONF_ENABLED=1
   DEMO_ENABLED=1
   EXAMPLES_ENABLED=1
else
   DOCS_ENABLED=$(isModuleEnabled "apidocs")
   CODE_ENABLED=$(isModuleEnabled "codepack")
   CONF_ENABLED=$(isModuleEnabled "configpack")
   DEMO_ENABLED=$(isModuleEnabled "demopack")
   EXAMPLES_ENABLED=$(isModuleEnabled "examples")
fi

####################################################################################################
# reset parameters for safety reasons
CODE_LOCAL_REPO_PATH=
DOCS_LOCAL_REPO_PATH=
CONFIG_LOCAL_REPO_PATH=
EXAMPLE_LOCAL_REPO_PATH=
BUILD_PATH=

# setup base paths
if [ -f $CONF ]
then
   echo "[INFO] Loading configuration file $CONF"
   source $CONF
else
   echo "[ERROR] Loading configuration file $CONF failed! Aborting!"
   exit 1
fi

# check configuration parameters' validity and manage default values
if [ -z "$CODE_LOCAL_REPO_PATH" ] || [ ! -d "$CODE_LOCAL_REPO_PATH" ]
then
   GIT_CODE_URL=https://github.com/AdventurePHP/code.git
else
   GIT_CODE_URL=$CODE_LOCAL_REPO_PATH
fi

if [ -z "$DOCS_LOCAL_REPO_PATH" ] || [ ! -d "$DOCS_LOCAL_REPO_PATH" ]
then
   GIT_DOCS_URL=https://github.com/AdventurePHP/docs.git
else
   GIT_DOCS_URL=$DOCS_LOCAL_REPO_PATH
fi

if [ -z "$CONFIG_LOCAL_REPO_PATH" ] || [ ! -d "$CONFIG_LOCAL_REPO_PATH" ]
then
   GIT_CONFIG_URL=https://github.com/AdventurePHP/config.git
else
   GIT_CONFIG_URL=$CONFIG_LOCAL_REPO_PATH
fi

if [ -z "$EXAMPLE_LOCAL_REPO_PATH" ] || [ ! -d "$EXAMPLE_LOCAL_REPO_PATH" ]
then
   GIT_EXAMPLES_URL=https://github.com/AdventurePHP/examples.git
else
   GIT_EXAMPLES_URL=$EXAMPLE_LOCAL_REPO_PATH
fi

if [ -z "$BUILD_PATH" ] || [ ! -d "$BUILD_PATH" ]
then
    echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"BUILD_PATH\" missing or invalid ot points to a non-existing directory!"
    exit 1
fi

####################################################################################################

echo "[INFO] Set global parameters ..."
RELEASEPATH=$BUILD_PATH/RELEASES
DISTRINAME=apf
BUILDNUMBR=$(date +"%Y-%m-%d-%H%M")
DISTRIARCH_NOARCH=noarch
DISTRIARCH_PHP5=php5

USER_NOBODY=nobody
GROUP_NOBODY=None

echo "[INFO] Current build version: $BUILDVERS-$BUILDNUMBR"

####################################################################################################

CURRENTRELEASEPATH=$RELEASEPATH/$BUILDVERS
mkdir -p $CURRENTRELEASEPATH

####################################################################################################

echo "[INFO] Exporting code branch $GIT_BRANCH to workspace ..."

# create source tree for code
WORKSPACE=$CURRENTRELEASEPATH/workspace
CODE_SOURCE_PATH=$WORKSPACE/code
DOCS_SOURCE_PATH=$WORKSPACE/docs
CONFIG_SOURCE_PATH=$WORKSPACE/config
EXAMPLES_SOURCE_PATH=$WORKSPACE/examples

mkdir -p $CODE_SOURCE_PATH
mkdir -p $DOCS_SOURCE_PATH
mkdir -p $CONFIG_SOURCE_PATH
mkdir -p $EXAMPLES_SOURCE_PATH

# clone code to local disk
if [ "$CODE_ENABLED" == "1" ] || [ "$EXAMPLES_ENABLED" == "1" ] || [ "$DOCS_ENABLED" == "1" ] || [ "$DEMO_ENABLED" == "1" ]
then
   cd $CODE_SOURCE_PATH
   git clone --depth 1 --branch $GIT_BRANCH $GIT_CODE_URL . >/dev/null 2>&1
   if [ $? -ne 0 ]
   then
      echo "[ERROR] Checkout of branch $GIT_BRANCH of $GIT_CODE_URL into local workspace failed!"
      displayFooter
      exit 1
   fi
   rm -rf $CODE_SOURCE_PATH/.git
fi

# clone docs to local disk
if [ "$DEMO_ENABLED" == "1" ]
then
   cd $DOCS_SOURCE_PATH
   git clone --depth 1 --branch master $GIT_DOCS_URL . >/dev/null 2>&1
   if [ $? -ne 0 ]
   then
      echo "[ERROR] Checkout of branch master of $GIT_DOCS_URL into local workspace failed!"
      displayFooter
      exit 1
   fi
   rm -rf $DOCS_SOURCE_PATH/.git
fi

# clone config to local disk
if [ "$CONF_ENABLED" == "1" ]
then
   cd $CONFIG_SOURCE_PATH
   git clone --depth 1 --branch $GIT_BRANCH $GIT_CONFIG_URL . >/dev/null 2>&1
   if [ $? -ne 0 ]
   then
      echo "[ERROR] Checkout of $GIT_BRANCH of $GIT_CONFIG_URL into local workspace failed!"
      displayFooter
      exit 1
   fi
   rm -rf $CONFIG_SOURCE_PATH/.git
fi

# clone examples to local disk
if [ "$DEMO_ENABLED" == "1" ] || [ "$EXAMPLES_ENABLED" == "1" ]
then
   cd $EXAMPLES_SOURCE_PATH
   git clone --depth 1 --branch $GIT_BRANCH $GIT_EXAMPLES_URL . >/dev/null 2>&1
   if [ $? -ne 0 ]
   then
      echo "[ERROR] Checkout of $GIT_BRANCH of $GIT_EXAMPLES_URL into local workspace failed!"
      displayFooter
      exit 1
   fi
   rm -rf $EXAMPLES_SOURCE_PATH/.git
fi

####################################################################################################

if [ "$DOCS_ENABLED" == "1" ]
then
   echo "[INFO] generate documentation"

   # create folder for docs generation
   DOCS_GENERATION_PATH=$WORKSPACE/api-docs
   mkdir -p $DOCS_GENERATION_PATH

   # generate docs injecting build configuration params
   cat "$DIR/apf_docs.conf" \
      | awk -v r=$BUILDVERS '{ gsub("{{VERSION}}", r); print $0; }' \
      | awk -v r=$CODE_SOURCE_PATH '{ gsub("{{SOURCE_FOLDER}}", r); print $0; }' \
      | awk -v r=$DOCS_GENERATION_PATH '{ gsub("{{DOCS_GENERATION_DIR}}", r); print $0; }' \
      | awk -v r=$DIR '{ gsub("{{BUILD_DIR}}", r); print $0; }' \
      | doxygen - > $DOCS_GENERATION_PATH/apf_docs.log 2>&1
fi

####################################################################################################

if [ "$DOCS_ENABLED" == "1" ]
then
   echo "[INFO] copy html documentation to current release folder"
   DOKU_HTML_PATH=$CURRENTRELEASEPATH/docs/html
   mkdir -p $DOKU_HTML_PATH

   cp -rf $DOCS_GENERATION_PATH/docs/*.html $DOCS_GENERATION_PATH/docs/*.png $DOCS_GENERATION_PATH/docs/*.css $DOCS_GENERATION_PATH/docs/*.js $DOKU_HTML_PATH

   # fix for STRIP_FROM_PATH that does not effect example page :(
   # $CODE_SOURCE_PATH -> /APF
   for FILE in $(grep -R "$CODE_SOURCE_PATH" $DOKU_HTML_PATH | cut -d ":" -f1 | sort | uniq)
   do
      sed -i -e "s#$CODE_SOURCE_PATH#/APF#g" $FILE;
   done

   # Fix for file names containing the build path (STRIP_FROM_PATH does not apply here :(). E.g.
   # _2cygdrive_2c_2_users_2_christian_2_entwicklung_2_build-_test_2_r_e_l_e_a_s_e_s_22_80_81_2workspf8abe746937a97cbc37659678b593e08.html)
   #
   # File name mapping table:
   #
   # +-------+--------+
   # | Old   | New    |
   # +-------+--------+
   # | /     | _2     |
   # +-------+--------+
   # | [A-Z] | _[a-z] |
   # +-------+--------+
   cd $DOKU_HTML_PATH
   REPLACED_BUILD_PATH=$(echo $BUILD_PATH | sed -e "s#/#_2#g" | sed -e "s#[A-Z]#_\L&#g")
   for FILE in $(ls $REPLACED_BUILD_PATH*)
   do
      # replace file name
      NEW_FILE_NAME=$(echo $FILE | sed -e "s#$REPLACED_BUILD_PATH##g");
      mv $FILE $NEW_FILE_NAME;

      # replace file name in html files
      for HTML_FILE in $(grep "$FILE" * | cut -d ":" -f1 | sort | uniq)
      do
         sed -i -e "s#$FILE#$NEW_FILE_NAME#g" $HTML_FILE;
      done
   done

   find $DOKU_HTML_PATH -type f -exec touch {} \;
   find $DOKU_HTML_PATH -type f -exec chmod 644 {} \;
   find $DOKU_HTML_PATH -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $DOKU_HTML_PATH
   #chgrp -R $GROUP_NOBODY $DOKU_HTML_PATH
fi

####################################################################################################

if [ "$DOCS_ENABLED" == "1" ]
then
   echo "[INFO] create zip documentation files"
   cd $CURRENTRELEASEPATH/docs

   # quick hack to have a folder named "docs" inside the archives without having to copy stuff
   mv html docs

   zip -gr9 $DISTRINAME-docs-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_NOARCH.zip docs >/dev/null 2>&1
   tar -czf $DISTRINAME-docs-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_NOARCH.tar.gz docs >/dev/null 2>&1
   tar -cjf $DISTRINAME-docs-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_NOARCH.tar.bz2 docs >/dev/null 2>&1

   # revert quick hack
   mv docs html
fi

####################################################################################################

if [ "$CODE_ENABLED" == "1" ] || [ "$DEMO_ENABLED" == "1" ] || [ "$EXAMPLES_ENABLED" == "1" ]
then
    echo "[INFO] build code bases for $DISTRIARCH_PHP5 release"
    mkdir -p $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF

    # code files
    rsync -rt --exclude="tests" $CODE_SOURCE_PATH/* $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/

    # license file
    cp $DIR/lgpl-3.0.txt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/

    find $CURRENTRELEASEPATH/$DISTRIARCH_PHP5 -type f -exec touch {} \;
    find $CURRENTRELEASEPATH/$DISTRIARCH_PHP5 -type f -exec chmod 644 {} \;
    find $CURRENTRELEASEPATH/$DISTRIARCH_PHP5 -type d -exec chmod 755 {} \;
    #chown -R $USER_NOBODY $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/
    #chgrp -R $GROUP_NOBODY $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/
fi

####################################################################################################

mkdir -p $CURRENTRELEASEPATH/download

####################################################################################################

if [ "$CODE_ENABLED" == "1" ]
then
   echo "[INFO] create codepack release for $DISTRIARCH_PHP5"
   CODEPACKZIPFILENAME_PHP5=$DISTRINAME-codepack-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_PHP5
   cd $CURRENTRELEASEPATH/$DISTRIARCH_PHP5
   zip -r $CODEPACKZIPFILENAME_PHP5.zip . >/dev/null 2>&1
   mv $CODEPACKZIPFILENAME_PHP5.zip $CURRENTRELEASEPATH/download/
   tar -czf $CODEPACKZIPFILENAME_PHP5.tar.gz * >/dev/null 2>&1
   mv $CODEPACKZIPFILENAME_PHP5.tar.gz $CURRENTRELEASEPATH/download/
   tar -cjf $CODEPACKZIPFILENAME_PHP5.tar.bz2 * >/dev/null 2>&1
   mv $CODEPACKZIPFILENAME_PHP5.tar.bz2 $CURRENTRELEASEPATH/download/
   cd - >/dev/null 2>&1
fi

####################################################################################################

if [ "$CONF_ENABLED" == "1" ]
then
   echo "[INFO] create configpack release"
   BUILDTMP_CONGIGPACK_PHP5=$CURRENTRELEASEPATH/configpack_noarch
   mkdir -p $BUILDTMP_CONGIGPACK_PHP5

   rsync -rt $CONFIG_SOURCE_PATH/* $BUILDTMP_CONGIGPACK_PHP5

   # license file
   cp $DIR/lgpl-3.0.txt $BUILDTMP_CONGIGPACK_PHP5/

   find $BUILDTMP_CONGIGPACK_PHP5 -type f -exec touch {} \;
   find $BUILDTMP_CONGIGPACK_PHP5 -type f -exec chmod 644 {} \;
   find $BUILDTMP_CONGIGPACK_PHP5 -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $BUILDTMP_CONGIGPACK_PHP5
   #chgrp -R $GROUP_NOBODY $BUILDTMP_CONGIGPACK_PHP5

   CONFIGPACKZIPFILENAME=$DISTRINAME-configpack-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_NOARCH
   cd $BUILDTMP_CONGIGPACK_PHP5

   zip -r $CONFIGPACKZIPFILENAME.zip . >/dev/null 2>&1
   mv $CONFIGPACKZIPFILENAME.zip $CURRENTRELEASEPATH/download/
   tar -czf $CONFIGPACKZIPFILENAME.tar.gz * >/dev/null 2>&1
   mv $CONFIGPACKZIPFILENAME.tar.gz $CURRENTRELEASEPATH/download/
   tar -cjf $CONFIGPACKZIPFILENAME.tar.bz2 * >/dev/null 2>&1
   mv $CONFIGPACKZIPFILENAME.tar.bz2 $CURRENTRELEASEPATH/download/
   cd - >/dev/null 2>&1
fi

####################################################################################################

if [ "$DEMO_ENABLED" == "1" ]
then
   echo "[INFO] generate demopack basis for $DISTRIARCH_PHP5"
   BUILDTMP_DEMOPACK_PHP5=$CURRENTRELEASEPATH/demopack_$DISTRIARCH_PHP5
   mkdir -p $BUILDTMP_DEMOPACK_PHP5

   # setup basic files
   rsync -rt $EXAMPLES_SOURCE_PATH/sandbox/* $BUILDTMP_DEMOPACK_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_DEMOPACK_PHP5/APF/

   # license file
   cp $DIR/lgpl-3.0.txt $BUILDTMP_DEMOPACK_PHP5/
   cp $DIR/MIT-LICENSE.txt $BUILDTMP_DEMOPACK_PHP5/

   # add images from the "normal" documentation page
   mkdir -p $BUILDTMP_DEMOPACK_PHP5/images
   cp $DOCS_SOURCE_PATH/media/img/apf-logo.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/err-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/hint-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/ok-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/warning-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/content/pagecontroller_timing_model.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/content/frontcontroller_timing_model_2.X.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/content/filter_timing_model.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/content/logger_concept_1_17.png $BUILDTMP_DEMOPACK_PHP5/images/

   # add selection of content
   mkdir -p $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_154_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_013_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_014_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_098_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_012_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_047_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_006_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_134_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_067_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_004_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_137_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_023_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_030_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_107_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_144_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_145_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_161_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/DOCS/pres/content/c_*_162_3.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/

   find $BUILDTMP_DEMOPACK_PHP5 -type f -exec touch {} \;
   find $BUILDTMP_DEMOPACK_PHP5 -type f -exec chmod 644 {} \;
   find $BUILDTMP_DEMOPACK_PHP5 -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $BUILDTMP_DEMOPACK_PHP5
   #chgrp -R $GROUP_NOBODY $BUILDTMP_DEMOPACK_PHP5
fi

####################################################################################################

if [ "$DEMO_ENABLED" == "1" ]
then
   echo "[INFO] create demopack release packages for $DISTRIARCH_PHP5"
   DEMOPACKZIPFILENAME_PHP5=$DISTRINAME-demopack-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_PHP5
   cd $BUILDTMP_DEMOPACK_PHP5
   zip -r $DEMOPACKZIPFILENAME_PHP5.zip . >/dev/null 2>&1
   mv $DEMOPACKZIPFILENAME_PHP5.zip $CURRENTRELEASEPATH/download/
   tar -czf $DEMOPACKZIPFILENAME_PHP5.tar.gz * >/dev/null 2>&1
   mv $DEMOPACKZIPFILENAME_PHP5.tar.gz $CURRENTRELEASEPATH/download/
   tar -cjf $DEMOPACKZIPFILENAME_PHP5.tar.bz2 * >/dev/null 2>&1
   mv $DEMOPACKZIPFILENAME_PHP5.tar.bz2 $CURRENTRELEASEPATH/download/
   cd - >/dev/null 2>&1
fi

####################################################################################################

if [ "$EXAMPLES_ENABLED" == "1" ]
then
   echo "[INFO] generate vbc example basis for $DISTRIARCH_PHP5"
   BUILDTMP_VBC_PHP5=$CURRENTRELEASEPATH/vbc_$DISTRIARCH_PHP5
   mkdir -p $BUILDTMP_VBC_PHP5

   # setup basic files
   rsync -rt $EXAMPLES_SOURCE_PATH/viewbasedcaching/* $BUILDTMP_VBC_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_VBC_PHP5/APF/

   # license file
   cp $DIR/lgpl-3.0.txt $BUILDTMP_VBC_PHP5/

   find $BUILDTMP_VBC_PHP5 -type f -exec touch {} \;
   find $BUILDTMP_VBC_PHP5 -type f -exec chmod 644 {} \;
   find $BUILDTMP_VBC_PHP5 -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $BUILDTMP_VBC_PHP5
   #chgrp -R $GROUP_NOBODY $BUILDTMP_VBC_PHP5
fi

####################################################################################################

if [ "$EXAMPLES_ENABLED" == "1" ]
then
   echo "[INFO] create vbc example release packages for $DISTRIARCH_PHP5"
   VBCZIPFILENAME_PHP5=$DISTRINAME-vbc-example-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_PHP5
   cd $BUILDTMP_VBC_PHP5
   zip -r $VBCZIPFILENAME_PHP5.zip . >/dev/null 2>&1
   mv $VBCZIPFILENAME_PHP5.zip $CURRENTRELEASEPATH/download/
   tar -czf $VBCZIPFILENAME_PHP5.tar.gz * >/dev/null 2>&1
   mv $VBCZIPFILENAME_PHP5.tar.gz $CURRENTRELEASEPATH/download/
   tar -cjf $VBCZIPFILENAME_PHP5.tar.bz2 * >/dev/null 2>&1
   mv $VBCZIPFILENAME_PHP5.tar.bz2 $CURRENTRELEASEPATH/download/
   cd - >/dev/null 2>&1
fi

####################################################################################################

if [ "$EXAMPLES_ENABLED" == "1" ]
then
   echo "[INFO] generate calc example basis for $DISTRIARCH_PHP5"
   BUILDTMP_CALC_PHP5=$CURRENTRELEASEPATH/calc_$DISTRIARCH_PHP5
   mkdir -p $BUILDTMP_CALC_PHP5

   # setup basic files
   rsync -rt $EXAMPLES_SOURCE_PATH/calc/* $BUILDTMP_CALC_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_CALC_PHP5/APF/

   # license file
   cp $DIR/lgpl-3.0.txt $BUILDTMP_CALC_PHP5/

   find $BUILDTMP_CALC_PHP5 -type f -exec touch {} \;
   find $BUILDTMP_CALC_PHP5 -type f -exec chmod 644 {} \;
   find $BUILDTMP_CALC_PHP5 -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $BUILDTMP_CALC_PHP5
   #chgrp -R $GROUP_NOBODY $BUILDTMP_CALC_PHP5
fi

####################################################################################################

if [ "$EXAMPLES_ENABLED" == "1" ]
then
   echo "[INFO] create calc example release packages for $DISTRIARCH_PHP5"
   CALCZIPFILENAME_PHP5=$DISTRINAME-calc-example-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_PHP5
   cd $BUILDTMP_CALC_PHP5
   zip -r $CALCZIPFILENAME_PHP5.zip . >/dev/null 2>&1
   mv $CALCZIPFILENAME_PHP5.zip $CURRENTRELEASEPATH/download/
   tar -czf $CALCZIPFILENAME_PHP5.tar.gz * >/dev/null 2>&1
   mv $CALCZIPFILENAME_PHP5.tar.gz $CURRENTRELEASEPATH/download/
   tar -cjf $CALCZIPFILENAME_PHP5.tar.bz2 * >/dev/null 2>&1
   mv $CALCZIPFILENAME_PHP5.tar.bz2 $CURRENTRELEASEPATH/download/
   cd - >/dev/null 2>&1
fi

####################################################################################################

if [ "$EXAMPLES_ENABLED" == "1" ]
then
   echo "[INFO] generate modules example basis for $DISTRIARCH_PHP5"
   BUILDTMP_MODS_PHP5=$CURRENTRELEASEPATH/mods_$DISTRIARCH_PHP5
   mkdir -p $BUILDTMP_MODS_PHP5

   # setup basic files
   rsync -rt $EXAMPLES_SOURCE_PATH/dynamic-modules/* $BUILDTMP_MODS_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_MODS_PHP5/APF/

   # license file
   cp $DIR/lgpl-3.0.txt $BUILDTMP_MODS_PHP5/

   find $BUILDTMP_MODS_PHP5 -type f -exec touch {} \;
   find $BUILDTMP_MODS_PHP5 -type f -exec chmod 644 {} \;
   find $BUILDTMP_MODS_PHP5 -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $BUILDTMP_MODS_PHP5
   #chgrp -R $GROUP_NOBODY $BUILDTMP_MODS_PHP5
fi

####################################################################################################

if [ "$EXAMPLES_ENABLED" == "1" ]
then
   echo "[INFO] create modules example release packages for $DISTRIARCH_PHP5"
   MODSZIPFILENAME_PHP5=$DISTRINAME-modules-example-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_PHP5
   cd $BUILDTMP_MODS_PHP5
   zip -r $MODSZIPFILENAME_PHP5.zip . >/dev/null 2>&1
   mv $MODSZIPFILENAME_PHP5.zip $CURRENTRELEASEPATH/download/
   tar -czf $MODSZIPFILENAME_PHP5.tar.gz * >/dev/null 2>&1
   mv $MODSZIPFILENAME_PHP5.tar.gz $CURRENTRELEASEPATH/download/
   tar -cjf $MODSZIPFILENAME_PHP5.tar.bz2 * >/dev/null 2>&1
   mv $MODSZIPFILENAME_PHP5.tar.bz2 $CURRENTRELEASEPATH/download/
   cd - >/dev/null 2>&1
fi

####################################################################################################

echo "[INFO] clean up temporary directories"
cd $CURRENTRELEASEPATH

if [ ! -z "$WORKSPACE" ] && [ -d "$WORKSPACE" ]
then
   rm -rf $WORKSPACE
fi

if [ ! -z "$CURRENTRELEASEPATH/$DISTRIARCH_PHP5" ] && [ -d "$CURRENTRELEASEPATH/$DISTRIARCH_PHP5" ]
then
   rm -rf $CURRENTRELEASEPATH/$DISTRIARCH_PHP5
fi

if [ ! -z "$BUILDTMP_DEMOPACK_PHP5" ] && [ -d "$BUILDTMP_DEMOPACK_PHP5" ]
then
   rm -rf $BUILDTMP_DEMOPACK_PHP5
fi

if [ ! -z "$BUILDTMP_CONGIGPACK_PHP5" ] && [ -d "$BUILDTMP_CONGIGPACK_PHP5" ]
then
   rm -rf $BUILDTMP_CONGIGPACK_PHP5
fi

if [ ! -z "$BUILDTMP_VBC_PHP5" ] && [ -d "$BUILDTMP_VBC_PHP5" ]
then
   rm -rf $BUILDTMP_VBC_PHP5
fi

if [ ! -z "$BUILDTMP_CALC_PHP5" ] && [ -d "$BUILDTMP_CALC_PHP5" ]
then
   rm -rf $BUILDTMP_CALC_PHP5
fi

if [ ! -z "$BUILDTMP_MODS_PHP5" ] && [ -d "$BUILDTMP_MODS_PHP5" ]
then
   rm -rf $BUILDTMP_MODS_PHP5
fi
####################################################################################################

displayFooter
exit 0

####################################################################################################
