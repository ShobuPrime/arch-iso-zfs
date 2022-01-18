#!/bin/bash
####
# simple wrapper to automate the steps from
#   https://wiki.archlinux.org/index.php/ZFS#Installation
#   and
#   https://wiki.archlinux.org/index.php/Archiso#Installing_packages
#
# @author stev leibelt <artodeto@bazzline.net>
# @since 2016-05-09
####

#begin of variables declaration
ARCHZFSKEY="DDF7DB817396A49B2A2723F7403BD972F75D9D76"
CURRENT_WORKING_DIRECTORY=$(pwd)
#declare -a LIST_OF_AVAILABLE_ZFS_PACKAGES=("archzfs-linux" "archzfs-linux-git" "archzfs-linux-lts")
#declare -a LIST_OF_AVAILABLE_ZFS_PACKAGES=("archzfs-linux" "archzfs-linux-git")
declare -a LIST_OF_AVAILABLE_ZFS_PACKAGES=("archzfs-linux")
LIST_OF_AVAILABLE_ZFS_PACKAGES_AS_STRING=""
PATH_OF_THIS_FILE=$(cd $(dirname "${BASH_SOURCE[0]}"); pwd)
PATH_TO_THE_DYNAMIC_DATA_DIRECTORY="${PATH_OF_THIS_FILE}/dynamic_data"
PATH_TO_THE_OUTPUT_DIRECTORY="${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/out"
PATH_TO_THE_PROFILE_DIRECTORY="/usr/share/archiso/configs/releng"
PATH_TO_THE_SOURCE_DATA_DIRECTORY="${PATH_OF_THIS_FILE}/source"
WHO_AM_I=$(whoami)
#end of variables declaration

#begin of check if we are root
if [[ ${WHO_AM_I} != "root" ]];
then
    echo ":: Script needs to be executed as root."

    exit 1
fi
#end of check if we are root

#begin of check if archiso is installed
if [[ ! -d ${PATH_TO_THE_PROFILE_DIRECTORY} ]];
then
    echo ":: No archiso package installed."
    echo ":: We are going to install it now..."
    pacman -Syyu archiso
fi
#end of check if archiso is installed

#begin of dynamic data directory exists
if [[ -d ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY} ]];
then
    DIRECTORY_IS_NOT_EMPTY="$(ls -A ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY})"

    if [[ ${DIRECTORY_IS_NOT_EMPTY} ]];
    then
        echo ":: Previous build data detected."
        echo ":: Cleaning up now..."
        for FILESYSTEM_ITEM_NAME in $(ls ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/ | grep -v out);
        do
            rm -fr ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/${FILESYSTEM_ITEM_NAME}
        done
    fi
else
    mkdir -p ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}
fi
#end of dynamic data directory exists

#begin of creating the output directory
mkdir -p ${PATH_TO_THE_OUTPUT_DIRECTORY}
#end of creating the output directory

#begin of copying needed profile
cp -r ${PATH_TO_THE_PROFILE_DIRECTORY}/ ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}
#end of copying needed profile

#begin of check if pacman-init.service file is still the same
FILE_PATH_TO_KEEP_THE_DIFF=$(mktemp)
FILE_PATH_TO_THE_SOURCE_PACMAN_INIT_SERVICE="/usr/share/archiso/configs/releng/airootfs/etc/systemd/system/pacman-init.service"
FILE_PATH_TO_OUR_PACMAN_INIT_SERVICE="${PATH_TO_THE_SOURCE_DATA_DIRECTORY}/pacman-init.service"
FILE_PATH_TO_PACMAN_INIT_SERVICE_EXPECTED_DIFF="${PATH_TO_THE_SOURCE_DATA_DIRECTORY}/pacman-init.service.expected_diff"

diff ${FILE_PATH_TO_THE_SOURCE_PACMAN_INIT_SERVICE} "${FILE_PATH_TO_OUR_PACMAN_INIT_SERVICE}" > ${FILE_PATH_TO_KEEP_THE_DIFF}

NUMBER_OF_LINES_BETWEEN_THE_TWO_DIFF_FILES=$(diff ${FILE_PATH_TO_KEEP_THE_DIFF} "${FILE_PATH_TO_PACMAN_INIT_SERVICE_EXPECTED_DIFF}" | wc -l)

if [[ ${NUMBER_OF_LINES_BETWEEN_THE_TWO_DIFF_FILES} -gt 0 ]];
then
    echo ":: Unexpected runtime environment."
    echo "   The diff between the files >>${FILE_PATH_TO_THE_SOURCE_PACMAN_INIT_SERVICE}<< and >>${FILE_PATH_TO_OUR_PACMAN_INIT_SERVICE}<< results in an unexpected output."
    echo "   Dumping expected diff:"
    echo "${FILE_PATH_TO_PACMAN_INIT_SERVICE_EXPECTED_DIFF}"
    echo ""
    echo "   Dumping current diff:"
    echo "${FILE_PATH_TO_KEEP_THE_DIFF}"
    echo ""
    echo ":: Please create an issue in >>https://github.com/stevleibelt/arch-linux-live-cd-iso-with-zfs/issues<<."
    echo ""
    echo ":: Will stop now."
    echo ""

    return 1;
else
    echo ":: Updating pacman-init.service"

    cp "${FILE_PATH_TO_OUR_PACMAN_INIT_SERVICE}" "${PATH_TO_THE_OUTPUT_DIRECTORY}/airootfs/etc/systemd/system/pacman-init.service"
fi
#end of check if pacman-init.service file is still the same

#begin of user interaction
if [[ ${#LIST_OF_AVAILABLE_ZFS_PACKAGES[*]} -gt 1 ]];
then
    #@todo ask what kind of archzfs the user wants to use:
    #   archzfs-linux (default)
    #   archzfs-linux-git
    #   archzfs-linux-lts
    for INDEX_KEY in "${!LIST_OF_AVAILABLE_ZFS_PACKAGES[@]}";
    do
        LIST_OF_AVAILABLE_ZFS_PACKAGES_AS_STRING+="   ${INDEX_KEY}) ${LIST_OF_AVAILABLE_ZFS_PACKAGES[${INDEX_KEY}]}"
    done;

    echo ":: There are ${#LIST_OF_AVAILABLE_ZFS_PACKAGES[@]} archzfs repositories available:"
    echo ":: Repositories"
    echo "${LIST_OF_AVAILABLE_ZFS_PACKAGES_AS_STRING}"
    echo ""
    read -p "Enter a selection (default=0): " SELECTED_ARCHZFS_REPOSITORY_INDEX
else
    SELECTED_ARCHZFS_REPOSITORY_INDEX=0
fi
#end of user interaction

#begin of adding archzfs repository and package

# Adding key for the archzfs repository
#pacman-key -r ${ARCHZFSKEY}
#pacman-key --lsign-key ${ARCHZFSKEY}


#@todo pretty shitty, we are defining the list above but this switch case needs a lot of maintenance
SELECTED_ARCHZFS_REPOSITORY_NAME=${LIST_OF_AVAILABLE_ZFS_PACKAGES[${SELECTED_ARCHZFS_REPOSITORY_INDEX}]}

echo ":: Building with archzfs repository ${SELECTED_ARCHZFS_REPOSITORY_NAME}"

echo "[archzfs]" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/pacman.conf
echo "Server = http://archzfs.com/\$repo/\$arch" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/pacman.conf
echo "Server = http://mirror.sum7.eu/archlinux/archzfs/\$repo/\$arch" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/pacman.conf
echo "Server = https://mirror.biocrafting.net/archlinux/archzfs/\$repo/\$arch" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/pacman.conf
case ${SELECTED_ARCHZFS_REPOSITORY_NAME} in
    "archzfs-linux-git" )
        echo "zfs-linux-git" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        echo "zfs-utils-git" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        ;;
    "archzfs-linux-lts" )
#@todo begin of support for lts
#@idea (uname -r | grep lts)?
#@see:
#   https://wiki.archlinux.org/index.php/Pacman -> IgnorePkg
#   https://blog.chendry.org/2015/02/06/automating-arch-linux-installation.html
#        echo "linux-lts" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.both
#        echo "linux-lts-headers" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.both
        echo "zfs-linux-lts" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        echo "zfs-utils-lts" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        echo "linux-lts" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        echo "linux-lts-headers" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        ;;
#@todo end of support for lts
    *)
        echo "zfs-linux" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        echo "zfs-utils" >> ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/packages.x86_64
        ;;
esac
#end of adding archzfs repository and package

#begin of cleanup
#cd ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}
BUILD_FILE_NAME="archlinux-${SELECTED_ARCHZFS_REPOSITORY_NAME}"
ISO_FILE_PATH="${PATH_TO_THE_OUTPUT_DIRECTORY}/${BUILD_FILE_NAME}.iso"
MD5_FILE_PATH="${ISO_FILE_PATH}.md5sum"
SHA1_FILE_PATH="${ISO_FILE_PATH}.sha1sum"
SHA512_FILE_PATH="${ISO_FILE_PATH}.sha512sum"

if [[ -f ${ISO_FILE_PATH} ]];
then
    echo ":: Older build detected"
    echo ":: Do you want to move the files somewhere? [y|N] (n means overwriting, n is default)"
    read MOVE_EXISTING_BUILD_FILES

    if [[ ${MOVE_EXISTING_BUILD_FILES} == "y" ]];
    then
        echo ":: Please input the path where you want to move the files (if the path does not exist, it will be created):"
        read PATH_TO_MOVE_THE_EXISTING_BUILD_FILES

        if [[ ! -d ${PATH_TO_MOVE_THE_EXISTING_BUILD_FILES} ]];
        then
            echo ":: Creating directory in path: ${PATH_TO_MOVE_THE_EXISTING_BUILD_FILES}"
            mkdir -p ${PATH_TO_MOVE_THE_EXISTING_BUILD_FILES}
        fi

        echo ":: Moving files ..."
        mv -v ${BUILD_FILE_NAME}* ${PATH_TO_MOVE_THE_EXISTING_BUILD_FILES}/
    else
        #following lines prevent us from getting asked from mv to override the existing file
        rm ${ISO_FILE_PATH}
        rm ${MD5_FILE_PATH}
        rm ${SHA1_FILE_PATH}
        rm ${SHA512_FILE_PATH}
    fi
fi
#end of cleanup

#begin of building
mkarchiso -v -w ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY} -o ${PATH_TO_THE_OUTPUT_DIRECTORY} ${PATH_TO_THE_PROFILE_DIRECTORY}

LAST_EXIT_CODE="$?"

if [[ ${LAST_EXIT_CODE} -gt 0 ]];
then
    echo ""
    echo ":: Build failed!"
    echo ":: Cleaning up now..."
    for FILESYSTEM_ITEM_NAME in $(ls ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/ | grep -v out);
    do
        rm -fr ${PATH_TO_THE_DYNAMIC_DATA_DIRECTORY}/${FILESYSTEM_ITEM_NAME}
    done
    exit ${LAST_EXIT_CODE}
fi
#end of building

#begin of renaming and hash generation
cd ${PATH_TO_THE_OUTPUT_DIRECTORY}

chmod -R 765 *

mv archlinux-*.iso ${ISO_FILE_PATH}
chown ${WHO_AM_I} ${ISO_FILE_PATH}
sha1sum ${ISO_FILE_PATH} > ${SHA1_FILE_PATH}
md5sum ${ISO_FILE_PATH} > ${MD5_FILE_PATH}
sha512sum ${ISO_FILE_PATH} > ${SHA512_FILE_PATH}
#end of renaming and hash generation

#@todo
#ask if we should dd this to a sdx device

echo ""
echo ":: Iso created in path:"
echo "   ${PATH_TO_THE_OUTPUT_DIRECTORY}"
echo ":: --------"
echo ":: Listing directory content, filterd by ${SELECTED_ARCHZFS_REPOSITORY_NAME}..."

ls -halt ${PATH_TO_THE_OUTPUT_DIRECTORY} | grep ${SELECTED_ARCHZFS_REPOSITORY_NAME}

cd ${CURRENT_WORKING_DIRECTORY}
