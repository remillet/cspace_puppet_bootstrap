#!/usr/bin/env bash

# bootstrap-cspace-modules.sh
#
# A bootstrap script for Debian- and RedHat-based Linux systems
# to install the CollectionSpace Puppet modules and their dependencies.

# This script must be run as 'root' (e.g. via 'sudo')

# Uncomment the following line for verbose output, useful when debugging
# set -x

PUPPET_OPTS='-v'
SCRIPT_NAME=`basename $0` # Note: script name may be misleading if script is symlinked
if [ "$EUID" -ne "0" ]; then
  echo "${SCRIPT_NAME}: This script must be run as root (e.g. via 'sudo') ..."
  exit 1
fi

# If the user provides a '-y' option to this script, the script
# will run entirely unattended. Otherwise, the user will later be
# queried as to whether they want to proceed with the installation,
# after the bootstrapping part of the script concludes successfully.

SCRIPT_RUNS_UNATTENDED=false
while getopts ":y" opt; do
  case $opt in
    # A '-y' option was entered on the command line.
    y)
      SCRIPT_RUNS_UNATTENDED=true
      ;;
    \?)
      # if any other command line options are supplied,
      # ignore them.
      ;;
  esac
done

# Verify that either the 'wget' or 'curl' executable file
# exists and is in the current PATH.

WGET_EXECUTABLE='wget'
WGET_FOUND=false
echo "Checking for existence of executable file '${WGET_EXECUTABLE}' ..."
if [ `command -v ${WGET_EXECUTABLE}` ]; then
  WGET_FOUND=true
fi

if [ $WGET_FOUND == true ]; then
  echo "Found executable file '${WGET_EXECUTABLE}' ..."
else 
  CURL_EXECUTABLE='curl'
  echo "Checking for existence of executable file '${CURL_EXECUTABLE}' ..."
  if [ `command -v ${CURL_EXECUTABLE}` ]; then
    echo "Found executable file '${CURL_EXECUTABLE}' ..."
  else
    echo "Could not find executable files '${WGET_EXECUTABLE}' or '${CURL_EXECUTABLE}'"
    # FIXME: Install wget or curl via a package manager, if both executables are not present.
    exit 1
  fi
fi

# Verify whether the 'apt-get' or 'yum' package manager
# executable files exist and are in the current PATH.

APT_GET_EXECUTABLE='apt-get'
APT_GET_EXECUTABLE_PATH=`command -v ${APT_GET_EXECUTABLE}`
YUM_EXECUTABLE='yum'
YUM_EXECUTABLE_PATH=`command -v ${YUM_EXECUTABLE}`
 
# Verify that the 'unzip' executable file exists and is
# in the current PATH. Install it if not already present.

UNZIP_EXECUTABLE='unzip'
echo "Checking for existence of executable file '${UNZIP_EXECUTABLE}' ..."
if [ ! `command -v ${UNZIP_EXECUTABLE}` ]; then
  # If the paths to both package manager executable files were not found
  # and 'unzip' isn't present, halt script execution with an error.
  # 'unzip' is required for actions to be performed later.
  if [ -z $APT_GET_EXECUTABLE_PATH ] && [ -z $YUM_EXECUTABLE_PATH ]; then
    echo "Could not find or install executable file ${UNZIP_EXECUTABLE}"
    exit 1
  fi
  # Otherwise, install 'unzip' via whichever package manager is available.
  if [ ! -z $APT_GET_EXECUTABLE_PATH ]; then
    echo "Installing '${UNZIP_EXECUTABLE}' ..."
    apt-get install unzip
    # TODO: Consider making checks for executable files into a function,
    # in part to avoid 'DRY' violation here and below.
    if [ ! `command -v ${UNZIP_EXECUTABLE}` ]; then
      echo "Could not find or install executable file ${UNZIP_EXECUTABLE}"
      exit 1
    fi
  elif [ ! -z $YUM_EXECUTABLE_PATH ]; then
    echo "Installing '${UNZIP_EXECUTABLE}' ..."
    yum -y install unzip
    if [ ! `command -v ${UNZIP_EXECUTABLE}` ]; then
      echo "Could not find or install executable file ${UNZIP_EXECUTABLE}"
      exit 1
    fi
  else
    echo "Could not install executable file ${UNZIP_EXECUTABLE}"
    exit 1
  fi
fi

# Install Puppet, if necessary
# This uses a bootstrap script created and maintained by Daniel Dreier,
# which works with several Linux distributions, including RedHat-based
# and Debian-based distros.

# Maintain the SHA-1 hash of a vetted commit of this file here.
# (Using 'master' instead of a specific commit makes downloading and running
# this script subject to security vulnerabilities and newly-introduced bugs.)

PUPPET_INSTALL_COMMIT='557c6bfe1dba1cf6f4491fed0b0628ecd6bdf7a4' # Latest commit on a branch as of 2014-02-19
PUPPET_INSTALL_GITHUB_PATH="https://raw.githubusercontent.com/danieldreier/vagrant-template/${PUPPET_INSTALL_COMMIT}/provision"
PUPPET_INSTALL_SCRIPT_NAME='install_puppet.sh'

if [ ! -e ./$PUPPET_INSTALL_SCRIPT_NAME ]; then
  echo "Downloading script for installing Puppet ..."
  moduleurl="${PUPPET_INSTALL_GITHUB_PATH}/${PUPPET_INSTALL_SCRIPT_NAME}"
  if [ $WGET_FOUND == true ]; then
    wget --no-verbose $moduleurl --output-document=$PUPPET_INSTALL_SCRIPT_NAME
  else
    curl --output $PUPPET_INSTALL_SCRIPT_NAME $moduleurl 
  fi
fi

echo "Installing Puppet, if it is not already installed ..."
if [ -e $PUPPET_INSTALL_SCRIPT_NAME ]; then
  chmod u+x $PUPPET_INSTALL_SCRIPT_NAME
  ./$PUPPET_INSTALL_SCRIPT_NAME
fi

# Verify that the 'puppet' executable file exists
# and is in the current PATH.

PUPPET_EXECUTABLE='puppet'
echo "Checking for existence of executable file '${PUPPET_EXECUTABLE}' ..."
if [ ! `command -v ${PUPPET_EXECUTABLE}` ]; then
  echo "Could not find executable file '${PUPPET_EXECUTABLE}'"
  exit 1
fi

# Verify that the default, system-wide Puppet module
# directory exists (even if it is a simlink). If Puppet is
# installed but this directory doesn't exist, there may have
# been some problem with its installation.

PUPPETPATH='/etc/puppet'
MODULEPATH="${PUPPETPATH}/modules"
echo "Checking for existence of Puppet module directory '$MODULEPATH' ..."
if [ ! -d "${MODULEPATH}" ]; then
  echo "Could not find Puppet module directory '$MODULEPATH'"
  exit 1
fi

# Install the CollectionSpace-related Puppet modules from GitHub.

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
  'cspace_user' \
  )

cd $MODULEPATH
let MODULE_COUNTER=0
for module in ${MODULES[*]}
  do
    echo "Downloading CollectionSpace Puppet module '${MODULES[MODULE_COUNTER]}' ..."
    module=${MODULES[MODULE_COUNTER]}
    moduleurl="$GITHUB_REPO/${module}/${GITHUB_ARCHIVE_PATH}/${GITHUB_ARCHIVE_FILENAME}"
    if [ $WGET_FOUND == true ]; then
      wget --no-verbose $moduleurl
    else
      # '--location' flag follows redirects
      curl --location --remote-name $moduleurl 
    fi
    echo "Extracting files from archive file '${GITHUB_ARCHIVE_FILENAME}' ..."
    unzip -q $GITHUB_ARCHIVE_FILENAME
    echo "Removing archive file ..."
    rm $GITHUB_ARCHIVE_FILENAME
    # GitHub's master branch ZIP archives, when exploded to a directory,
    # have a '-master' suffix that must be removed.
    # When doing this renaming, first rename any existing directory
    # that might cause a name collision when that suffix is removed.
    if [ -d "${module}" ]; then
      moved_old_module_name=`mktemp -t -d ${module}.XXXXX` || exit 1
      mv $module $moved_old_module_name
      echo "Backed up existing module to $moved_old_module_name ..."
    fi
    echo "Renaming module directory ..."
    mv "${module}${GITHUB_ARCHIVE_MASTER_SUFFIX}" $module
    let MODULE_COUNTER++
  done

# Install any Puppet Forge-hosted Puppet modules on which the
# CollectionSpace Puppet modules depend.

echo "Downloading required Puppet modules from Puppet Forge ..."
PF_MODULES+=( 
  'puppetlabs-inifile' \
  'puppetlabs-postgresql' \
  'puppetlabs-stdlib' \
  'puppetlabs-vcsrepo' \
  )
let PF_COUNTER=0
for pf_module in ${PF_MODULES[*]}
  do
    # Uninstallation, followed by installation, appears to be necessary
    # to pick up dependency modules.
    echo "Uninstalling Puppet module ${PF_MODULES[PF_COUNTER]} (if present) ..."
    puppet module uninstall --force --modulepath=$MODULEPATH ${PF_MODULES[PF_COUNTER]} > /dev/null 2>&1
    echo "Installing Puppet module ${PF_MODULES[PF_COUNTER]} ..."
    puppet module install --modulepath=$MODULEPATH ${PF_MODULES[PF_COUNTER]}
    let PF_COUNTER++
  done
  
# The following function needs to be declared before the code
# which calls it.
#
# Compare two 'dotted' version numbers (e.g. 1.9, 1.8.22, etc.)
# Returns the result in a global variable:
# version_equals_or_exceeds_check
# Returns 0 if supplied version is >= than checked-for version.
# Returns 1 if checked-for version is greater.
# Echoes versions, one per line, deleting blank lines, if any.
# Then sorts with '-t.', specifying that the dot character (.)
# is used as a field separator, and sorting respectively on the
# first four fields of the dotted version number, via 'nr', thus
# performing a reverse numeric sort, so that the highest version
# number appears on line 1 of the output.
#
# Based on aspects of this approach (as modified by reader comment):
# http://fitnr.com/bash-comparing-version-strings.html#comment-221464671
# and this one, as well:
# http://stackoverflow.com/a/4495368
#
# TODO: Consider returning just true and false values, and revising the
# invocations of this function accordingly.
check_version()
{
    local version_supplied=$1 version_checked=$2
    local winner=$(echo -e "$version_supplied\n$version_checked" \
      | sed '/^$/d' \
      | sort -t. -k 1,1nr -k 2,2nr -k 3,3nr -k 4,4nr \
      | head -1)
    if [[ $version_supplied == $winner ]] ; then
        version_equals_or_exceeds_checked_version=true
    else
        version_equals_or_exceeds_checked_version=false
    fi
}

# Set the Puppet modulepath in the main Puppet configuration file (an INI-style file)
# by invoking the 'ini_setting' resource in the 'puppetlabs-inifile' module.
#
# (Note: when constructing Puppet resources below, the interpolation of variables
# within single-quotes is done here in 'bash'; that would not be performed in Puppet.)

echo "Setting 'modulepath' in the main Puppet configuration file ..."
# Physical path to Puppet's configuration directory.
# The path below is for a standalone, non-Puppet Enterprise deployment of Puppet.
# For documentation on this configuration directory and its system-specific locations, see:
# http://docs.puppetlabs.com/puppet/latest/reference/dirs_confdir.html 
PUPPET_CONFIG_PATH='/etc/puppet'
# Variable holding the path to Puppet's configuration directory, used in its own
# configuration files.
PUPPET_CONFIG_VAR='$confdir' # The '$' is a literal character in this context
MODULES_DIRECTORY_NAME='modules'
# In Puppet 3.5, the 'basemodulepath' setting effectively replaced the
# 'modulepath' setting for identifying the path to Puppet's default
# modules directory. As a result, we will need to set 'modulepath' in
# Puppet <= 3.4 and 'basemodulepath' in Puppet >= 3.5.
BASEMODULEPATH_INTRODUCED_IN=3.5
PUPPET_VERSION=`puppet --version`
check_version $PUPPET_VERSION $BASEMODULEPATH_INTRODUCED_IN
if $version_equals_or_exceeds_checked_version ; then
  MODULE_PATH_SETTING_NAME='basemodulepath'
else
  MODULE_PATH_SETTING_NAME='modulepath'
fi

modulepath_ini_resource="ini_setting { 'Set basemodulepath or modulepath in puppet.conf': "
modulepath_ini_resource+="  path    => '${PUPPET_CONFIG_PATH}/puppet.conf', "
modulepath_ini_resource+="  section => 'main', "
modulepath_ini_resource+="  setting => '${MODULE_PATH_SETTING_NAME}', "
modulepath_ini_resource+="  value   => '${PUPPET_CONFIG_VAR}/${MODULES_DIRECTORY_NAME}', "
modulepath_ini_resource+="  ensure  => 'present', "
modulepath_ini_resource+="} "

puppet apply ${PUPPET_OPTS} --modulepath $MODULEPATH -e "${modulepath_ini_resource}"

# Enable random ordering of unrelated resources on each run,
# in a manner similar to the above.
# "This can work like a fuzzer for shaking out undeclared dependencies." See:
# http://docs.puppetlabs.com/references/latest/configuration.html#ordering

echo "Setting 'ordering' in the main Puppet configuration file ..."
ordering_ini_resource="ini_setting { 'Set ordering in puppet.conf': "
ordering_ini_resource+="  path    => '${PUPPETPATH}/puppet.conf', "
ordering_ini_resource+="  section => 'main', "
ordering_ini_resource+="  setting => 'ordering', "
ordering_ini_resource+="  value   => 'random', "
ordering_ini_resource+="  ensure  => 'present', "
ordering_ini_resource+="} "

puppet apply ${PUPPET_OPTS} --modulepath $MODULEPATH -e "${ordering_ini_resource}"

# Create a default (initially minimal) Hiera configuration file.
#
# TODO: For suggestions related to a plausible initial, non-minimal
# Hiera configuration, see:
# http://puppetlabs.com/blog/writing-great-modules-part-2

# By writing at least a single document separator ('---')
# to the hiera.yaml file, rather than leaving that file empty, this
# avoids an "Error from DataBinding 'hiera' while looking up
# 'cspace_user::user_acct_name': no implicit conversion from nil to integer ...",
# at least under Ubuntu 13.10. See:
# https://bugs.launchpad.net/ubuntu/+source/puppet/+bug/1246229/comments/6

echo "Creating default Hiera configuration file ..."
hiera_config="file { 'Hiera config':"
hiera_config+="  path    => '${PUPPETPATH}/hiera.yaml', "
hiera_config+="  content => '---', "
hiera_config+="} "

puppet apply ${PUPPET_OPTS} --modulepath $MODULEPATH -e "${hiera_config}"

# Create a shell script that installs a CollectionSpace server instance.

echo "Creating installer script ..."
BIN_DIRECTORY='/usr/local/bin'
if [ -d "$BIN_DIRECTORY" ]; then
  installer_script_dir=$BIN_DIRECTORY
else
  installer_script_dir=$PUPPETPATH
fi
installer_script_filename='install_collectionspace.sh'
installer_script_path="${installer_script_dir}/${installer_script_filename}"
installer_script_contents="/bin/bash\n"
installer_script_contents+="sudo puppet apply ${PUPPET_OPTS} ${MODULEPATH}/puppet/manifests/site.pp\n"
installer_script_contents+="sudo puppet apply ${PUPPET_OPTS} ${MODULEPATH}/puppet/manifests/post-java.pp\n"
installer_file_resource="file { 'Creating installer script file': "
installer_file_resource+="  path    => '${installer_script_path}', "
installer_file_resource+="  content => \"#!${installer_script_contents}\", "
installer_file_resource+="  mode    => '744', "
installer_file_resource+="} "

puppet apply ${PUPPET_OPTS} --modulepath $MODULEPATH -e "${installer_file_resource}"

echo "--------------------------------------------------------------------------"
echo -e "\n"
echo "Congratulations!"
echo "Initial prerequisites for a CollectionSpace server were successfully installed.."
echo -e "\n"

# Depending on whether the '-y' flag was entered as a command line option when
# this script was executed, either ask the user whether they wish to proceed with
# the installation (if no '-y' flag), or just proceed without asking (if '-y' flag).

if [ $SCRIPT_RUNS_UNATTENDED == false ]; then
  read -p "Install your CollectionSpace server now [y/n]?" choice
  case "$choice" in
    # The user has entered a 'y' or 'Y' at the prompt, signifying they want
    # to continue the installation.
    # (This avoids redundant code by setting a flag, then falling through
    # to the next 'if' block below.)
    y|Y )
      SCRIPT_RUNS_UNATTENDED=true
    ;;
    # The user has entered any other value at the prompt, signifying they
    # do not want to continue the installation at this time.
    * )
      echo -e "\n"
      echo "You can later install your CollectionSpace server by entering the command:"
      if [ -x $installer_script_path ]; then
        echo "sudo $installer_script_path"
      else
        echo "sudo puppet apply ${PUPPET_OPTS} ${MODULEPATH}/puppet/manifests/site.pp"
        echo "... and then the command ..."
        echo "sudo puppet apply ${PUPPET_OPTS} ${MODULEPATH}/puppet/manifests/post-java.pp"
      fi
    ;;
  esac
fi

if [ $SCRIPT_RUNS_UNATTENDED == true ]; then
  echo "Starting installation ..."
  if [ -x "$installer_script_path" ]; then
    sudo $installer_script_path
  else
    sudo puppet apply ${PUPPET_OPTS} $MODULEPATH/puppet/manifests/site.pp
    EXIT_STATUS=$?
    if [ $EXIT_STATUS eq 0 ]; then
      sudo puppet apply ${PUPPET_OPTS} $MODULEPATH/puppet/manifests/post-java.pp
    else
      echo "Installation of the CollectionSpace server failed: see output for details."
    fi
  fi
fi

