#!/bin/bash

# bootstrap-cspace-modules.sh
#
# A bootstrap script for Debian- and RedHat-based Linux systems
# to install the CollectionSpace Puppet modules and their dependencies.

# This script must be run as 'root' (e.g. via 'sudo')

# Verify that the 'puppet' executable file exists
# and is in the current PATH.

PUPPET_EXECUTABLE='puppet'
echo "Checking for existance of executable file '${PUPPET_EXECUTABLE}' ..."
if [ ! `command -v ${PUPPET_EXECUTABLE}` ]; then
  echo "Could not find executable file '${PUPPET_EXECUTABLE}'"
  exit 1
fi

# Verify that the default, system-wide Puppet module
# directory exists (even if it is a simlink). If Puppet is
# installed but this directory doesn't exist, there may have
# been some problem with that installation.

MODULEPATH='/etc/puppet/modules'
echo "Checking for existance of Puppet module directory '$MODULEPATH' ..."
if [ ! -d "${MODULEPATH}" ]; then
  echo "Could not find Puppet module directory '$MODULEPATH'"
  exit 1
fi

# Verify that the 'wget' executable file exists
# and is in the current PATH. (The existence of 'wget'
# should have previously been ensured by running the 
# appropriate 'hashicorp/puppet-bootstrap' script.)

WGET_EXECUTABLE='wget'
echo "Checking for existance of executable file '${WGET_EXECUTABLE}' ..."
if [ ! `command -v ${WGET_EXECUTABLE}` ]; then
  echo "Could not find executable file '${WGET_EXECUTABLE}'"
  exit 1
fi

# Verify whether the 'apt-get' or 'yum' executable files
# exist and are in the current PATH.

APT_GET_EXECUTABLE='apt-get'
APT_GET_EXECUTABLE_PRESENT=`command -v ${APT_GET_EXECUTABLE}`
YUM_EXECUTABLE='yum'
YUM_EXECUTABLE_PRESENT=`command -v ${YUM_EXECUTABLE}`
  
# Verify that the 'unzip' executable file exists and is
# in the current PATH. Install it if not already present.

UNZIP_EXECUTABLE='unzip'
echo "Checking for existance of executable file '${UNZIP_EXECUTABLE}' ..."
if [ ! `command -v ${UNZIP_EXECUTABLE}` ]; then
  if [ ! APT_GET_EXECUTABLE_PRESENT ] || [ ! YUM_EXECUTABLE_PRESENT ]; then
    echo "Could not find or install executable file ${UNZIP_EXECUTABLE}"
    exit 1
  fi
  if [ APT_GET_EXECUTABLE_PRESENT ]; then
    echo "Installing '${UNZIP_EXECUTABLE}' ..."
    apt-get install unzip
  elif [ YUM_EXECUTABLE_PRESENT ]; then
    echo "Installing '${UNZIP_EXECUTABLE}' ..."
    yum install unzip
  else
    echo "Could not install executable file ${UNZIP_EXECUTABLE}"
    exit 1
  fi
fi

# Install the CollectionSpace modules from GitHub

GITHUB_REPO='https://github.com/cspace-puppet'
GITHUB_ARCHIVE_PATH='archive'
GITHUB_ARCHIVE_FILENAME='master.zip'
GITHUB_ARCHIVE_MASTER_SUFFIX='-master'
MODULES+=( 
  'puppet' \
  'cspace_environment' \
  'cspace_server_dependencies' \
  'cspace_java' \
  'cspace_postgresql_server' \
  'cspace_tarball' \
  'cspace_source' \
  )

cd $MODULEPATH
echo `pwd`
let MODULE_COUNTER=0
for module in ${MODULES[*]}
do
  echo "Downloading CollectionSpace Puppet module '${MODULES[MODULE_COUNTER]}' ..."
  module=${MODULES[MODULE_COUNTER]}
  moduleurl="$GITHUB_REPO/${module}/${GITHUB_ARCHIVE_PATH}/${GITHUB_ARCHIVE_FILENAME}"
  wget $moduleurl
  unzip $GITHUB_ARCHIVE_FILENAME
  rm $GITHUB_ARCHIVE_FILENAME
  # GitHub's master branch ZIP archives, when exploded to a directory,
  # have a '-master' suffix that must be removed.
  # When doing this renaming, first rename any existing directory
  # with the target name to avoid collisions.
  if [ -d "${module}" ]; then
    moved_old_module_name=`mktemp -t -d ${module}.XXXXX` || exit 1
    mv $module $moved_old_module_name
    echo "Backed up existing module to $moved_old_module_name ..."
  fi
  echo "Renaming CollectionSpace module directory ..."
  mv "${module}${GITHUB_ARCHIVE_MASTER_SUFFIX}" $module
  let MODULE_COUNTER++
done

# Install any modules from Puppet Forge on which the CollectionSpace
# modules depend.

echo "Downloading required Puppet modules from Puppet Forge ..."
# The 'puppetlabs/postgresql' module also installs 'puppetlabs/stdlib',
# another dependency, so it isn't necessary to install the latter separately.
puppet module install --force --modulepath=$MODULEPATH puppetlabs/postgresql
puppet module install --force --modulepath=$MODULEPATH puppetlabs/vcsrepo

