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
# process params:
# - svntree="1.10": used to get the release files from the svn (branches/[php4|php5]/<svntree>)
# - buildvers="1.10-RC1": the number of the build used in the file names
# - config file location: configuration file to setup e.g. svn path, docs output part
#
CONF=
SVNTREE=
BUILDVERS=
MODULES=all
while getopts "s:v:c:m:" option
do
  case $option in
    c) CONF=$OPTARG;;
    s) SVNTREE=$OPTARG;;
    v) BUILDVERS=$OPTARG;;
    m) MODULES=$OPTARG;;
  esac
done
shift $(($OPTIND - 1))

# check params
if [ -z "$CONF" ] || [ -z "$SVNTREE" ] || [ -z "$BUILDVERS" ] || [ -z "$MODULES" ]
then
   echo "[ERROR] not enough arguments"
   echo "Usage: $(basename $0) -c <config-file> -s <svn-subtree> -v <build-version> [-m <modules-to-build>]"
   echo
   echo "Please note: <subversion-subtree> must be replaced with the current version number of the SVN sub-tree and <build-version> indicates the version number in the release files."
   echo "The configuration file referred to must specify the following parameters:"
   echo
   echo "- DOCS_SOURCE_PATH: The source location where the APF documentation page is checked out on local disk."
   echo "- CODE_SOURCE_PATH: The source location where the APF sources are checked out on local disk."
   echo "- BUILDPATH       : The path where the build is created and stored."
   echo "- DOKUPPATH       : The path where the documentation is generated at."
   echo "- DOKULOGPATH     : The path where the documentation generation logs are stored."
   echo "- DOXYGEN_BIN     : The doxygen binary."
   echo
   echo "The list of modules (-m) can either be \"all\" (default) or a comma-separated list of the following items:"
   echo
   echo "- docs      : APF doxygen documentation."
   echo "- codepack  : Code release files."
   echo "- configpack: Sample configuration files."
   echo "- demopack  : Sandbox release files."
   echo "- examples  : Implementation examples (vbc, modules, calc)."
   exit 1
fi

# gather current directory
DIR=$(cd $(basename "$0") && pwd)

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
   DOCS_ENABLED=$(isModuleEnabled "docs")
   CODE_ENABLED=$(isModuleEnabled "codepack")
   CONF_ENABLED=$(isModuleEnabled "configpack")
   DEMO_ENABLED=$(isModuleEnabled "demopack")
   EXAMPLES_ENABLED=$(isModuleEnabled "examples")
fi

# special parameter for generic code base
BASE_ENABLED=0
if [ "$CODE_ENABLED" == "1" ] || [ "$DEMO_ENABLED" == "1" ] || [ "$EXAMPLES_ENABLED" == "1" ]
then
   BASE_ENABLED=1
fi

####################################################################################################
# setup base paths
if [ -f $CONF ]
then
   echo "[INFO] Loading configuration file $CONF"
   source $CONF
else
   echo "[ERROR] Loading configuration file $CONF failed! Aborting!"
   exit 1
fi

# check configuration parameters' validity
if [ -z "$DOCS_SOURCE_PATH" ] || [ ! -d "$DOCS_SOURCE_PATH" ]
then
    echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"DOCS_SOURCE_PATH\" missing or invalid!"
    exit 1
fi

if [ -z "$CODE_SOURCE_PATH" ] || [ ! -d "$CODE_SOURCE_PATH" ]
then
    echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"CODE_SOURCE_PATH\" missing or invalid!"
    exit 1
fi

if [ -z "$BUILDPATH" ] || [ ! -d "$BUILDPATH" ]
then
    echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"BUILDPATH\" missing or invalid!"
    exit 1
fi

if [ "$DOCS_ENABLED" == "1" ] && ([ -z "$DOKUPPATH" ] || [ ! -d "$DOKUPPATH" ])
then
   echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"DOKUPPATH\" missing or invalid!"
   exit 1
fi

if [ "$DOCS_ENABLED" == "1" ] && ([ -z "$DOKULOGPATH" ] || [ ! -d "$DOKULOGPATH" ])
then
   echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"DOKULOGPATH\" missing or invalid!"
   exit 1
fi

if [ "$DOCS_ENABLED" == "1" ] && ([ -z "$DOXYGEN_BIN" ] || [ ! -x "$DOXYGEN_BIN" ])
then
   echo "[ERROR] Loading configuration file $CONF failed! Configuration directive \"DOXYGEN_BIN\" missing or invalid!"
   exit 1
fi

####################################################################################################

echo "[INFO] Set global parameters"
RELEASEPATH=$BUILDPATH/RELEASES
DISTRINAME=apf
BUILDNUMBR=$(date +"%Y-%m-%d-%H%M")
DISTRIARCH_NOARCH=noarch
DISTRIARCH_PHP5=php5

USER_NOBODY=nobody
GROUP_NOBODY=None

echo "[INFO] current version to build: '$BUILDVERS-$BUILDNUMBR'"

####################################################################################################

CURRENTRELEASEPATH=$RELEASEPATH/$BUILDVERS
mkdir -p $CURRENTRELEASEPATH

####################################################################################################

if [ "$DOCS_ENABLED" == "1" ]
then
   echo "[INFO] generate documentation"
   if [ ! -z "$DOKULOGPATH" ]
   then
      rm -f $DOKULOGPATH/* >/dev/null 2>&1
   fi

   if [ ! -z "$DOKUPPATH" ]
   then
      rm -rf $DOKUPPATH/* >/dev/null 2>&1
   fi

   # TODO refactor to use with GIT repo structure (source location different, structure different, ...)
   cat "$DIR/apf_docs.conf" | sed -e "s/{{VERSION}}/$BUILDVERS/" -e "s/{{SVNTREE}}/$SVNTREE/g" -e "s/{{DOCS_GENERATION_DIR}}/$DOKUPPATH/" -e "s/{{BUILD_DIR}}//" -e "s/{{BUILD_DIR}}/$DIR/"| $DOXYGEN_BIN - > $DOKULOGPATH/apf_docs.log 2> $DOKULOGPATH/apf_docs.err
fi

####################################################################################################

if [ "$DOCS_ENABLED" == "1" ]
then
   echo "[INFO] copy html documentation to current release folder"
   DOKU_HTML_PATH=$CURRENTRELEASEPATH/docs/html
   mkdir -p $DOKU_HTML_PATH

   cp -rf $DOKUPPATH/docs/*.html $DOKUPPATH/docs/*.png $DOKUPPATH/docs/*.css $DOKUPPATH/docs/*.js $DOKU_HTML_PATH

   # fix for STRIP_FROM_PATH does not effect example page :(
   STRIP_FROM_PATH=$(cat "$DIR/apf_docs.conf" | grep -e "^STRIP_FROM_PATH" | cut -d "=" -f 2 | tr -d " " | sed -e "s/{{SVNTREE}}/$SVNTREE/g" -e "s/\//\\\\\//g")
   for file in $(grep -R "$STRIP_FROM_PATH" $DOKU_HTML_PATH | cut -d ":" -f1 | sort | uniq)
   do
      sed -i -e "s/$STRIP_FROM_PATH/\/APF/g" $file;
   done;

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

if [ "$BASE_ENABLED" == "1" ]
then
    echo "[INFO] build code bases for $DISTRIARCH_PHP5 release"
    mkdir -p $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF

    # code files
    rsync -rt --exclude=".svn" --exclude=".git" --exclude="/config" --exclude="examples" --exclude="tests" $CODE_SOURCE_PATH/php5/$SVNTREE/* $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/

    # license file
    cp $BUILDPATH/lgpl-3.0.txt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/

    find $CURRENTRELEASEPATH/$DISTRIARCH_PHP5 -type f -exec touch {} \;
    find $CURRENTRELEASEPATH/$DISTRIARCH_PHP5 -type f -exec chmod 644 {} \;
    find $CURRENTRELEASEPATH/$DISTRIARCH_PHP5 -type d -exec chmod 755 {} \;
    #chown -R $USER_NOBODY $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/
    #chgrp -R $GROUP_NOBODY $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/
fi

####################################################################################################

if [ "$BASE_ENABLED" == "1" ]
then
   mkdir -p $CURRENTRELEASEPATH/download
fi

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

   rsync -rt --exclude=".svn" --exclude=".git" $CODE_SOURCE_PATH/php5/$SVNTREE/config/* $BUILDTMP_CONGIGPACK_PHP5/config

   # license file
   cp $BUILDPATH/lgpl-3.0.txt $BUILDTMP_CONGIGPACK_PHP5/

   find $BUILDTMP_CONGIGPACK_PHP5 -type f -exec touch {} \;
   find $BUILDTMP_CONGIGPACK_PHP5 -type f -exec chmod 644 {} \;
   find $BUILDTMP_CONGIGPACK_PHP5 -type d -exec chmod 755 {} \;
   #chown -R $USER_NOBODY $BUILDTMP_CONGIGPACK_PHP5
   #chgrp -R $GROUP_NOBODY $BUILDTMP_CONGIGPACK_PHP5

   CONFIGPACKZIPFILENAME=$DISTRINAME-configpack-$BUILDVERS-$BUILDNUMBR-$DISTRIARCH_NOARCH
   cd $BUILDTMP_CONGIGPACK_PHP5

   # TODO: fix license file inclusion
   zip -r $CONFIGPACKZIPFILENAME.zip config -i "\*.ini" -i "\*.sql" >/dev/null 2>&1
   mv $CONFIGPACKZIPFILENAME.zip $CURRENTRELEASEPATH/download/
   tar --exclude=.svn --exclude=.git -czf $CONFIGPACKZIPFILENAME.tar.gz config >/dev/null 2>&1
   mv $CONFIGPACKZIPFILENAME.tar.gz $CURRENTRELEASEPATH/download/
   tar --exclude=.svn --exclude=.git -cjf $CONFIGPACKZIPFILENAME.tar.bz2 config >/dev/null 2>&1
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
   rsync -rt --exclude=".svn" --exclude=".git" $CODE_SOURCE_PATH/php5/$SVNTREE/examples/sandbox/* $BUILDTMP_DEMOPACK_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_DEMOPACK_PHP5/APF/

   # license file
   cp $BUILDPATH/lgpl-3.0.txt $BUILDTMP_DEMOPACK_PHP5/
   cp $BUILDPATH/MIT-LICENSE.txt $BUILDTMP_DEMOPACK_PHP5/

   # add images from the "normal" documentation page
   cp $DOCS_SOURCE_PATH/media/img/apf-logo.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/err-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/hint-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/ok-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/img/icons/warning-box.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/content/pagecontroller_timing_model.png $BUILDTMP_DEMOPACK_PHP5/images/
   cp $DOCS_SOURCE_PATH/media/content/frontcontroller_timing_model.png $BUILDTMP_DEMOPACK_PHP5/images/

   # add selection of content
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_154_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_013_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_014_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_098_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_012_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_047_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_006_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_134_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_067_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_004_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_137_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_023_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_030_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_107_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_144_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/
   cp $DOCS_SOURCE_PATH/APF/sites/apf/pres/content/c_*_145_2.X_*.html $BUILDTMP_DEMOPACK_PHP5/APF/sandbox/pres/content/

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
   rsync -rt --exclude=".svn" --exclude=".git" --exclude="README.txt" $CODE_SOURCE_PATH/php5/$SVNTREE/examples/viewbasedcaching/* $BUILDTMP_VBC_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_VBC_PHP5/APF/

   # license file
   cp $BUILDPATH/lgpl-3.0.txt $BUILDTMP_VBC_PHP5/

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
   rsync -rt --exclude=".svn" --exclude=".git" --exclude="README.txt" $CODE_SOURCE_PATH/php5/$SVNTREE/examples/calc/* $BUILDTMP_CALC_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_CALC_PHP5/APF/

   # license file
   cp $BUILDPATH/lgpl-3.0.txt $BUILDTMP_CALC_PHP5/

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
   rsync -rt --exclude=".svn" --exclude=".git" --exclude="README.txt" $CODE_SOURCE_PATH/php5/$SVNTREE/examples/dynamic-modules/* $BUILDTMP_MODS_PHP5/

   # add framework code
   rsync -rt $CURRENTRELEASEPATH/$DISTRIARCH_PHP5/APF/* $BUILDTMP_MODS_PHP5/APF/

   # license file
   cp $BUILDPATH/lgpl-3.0.txt $BUILDTMP_MODS_PHP5/

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

echo
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo -n "end at  : "
date +"%Y-%m-%d, %H:%M:%S"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
exit 0

####################################################################################################
