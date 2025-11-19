#!/bin/sh

set -ex
export ARCH="$(uname -m)"

APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
#export UPINFO="gh-releases-zsync|$(echo $GITHUB_REPOSITORY | tr '/' '|')|$VERSION|*$ARCH.AppImage.zsync"

sed -i 's|EUID == 0|EUID == 69|g' /usr/bin/makepkg
VERSION=$(grep 'pkgver=' PKGBUILD | awk -F '=' '{print $2}')
cd PrusaSlicer
makepkg -s --noconfirm --noprogressbar --needed

ls -l /usr
ls -l /usr/share
ls -l /usr/share/applications
ls -l ~/build
ls -l ~/build/packages

# NOW MAKE APPIMAGE
#SHARUN="https://raw.githubusercontent.com/sarrchri/prusaslicer-appimage/refs/heads/main/quick-sharun.sh"
#export OUTPUT_APPIMAGE=1
export OUTNAME=PrusaSlicer-"$VERSION"-"$ARCH".AppImage
#export DESKTOP=/usr/share/PrusaSlicer/applications/PrusaSlicer.desktop
#export ICON=/usr/share/PrusaSlicer/icons/PrusaSlicer.png
export LOCALE_FIX=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1

# ADD LIBRARIES
#wget --retry-connrefused --tries=30 "$SHARUN"
chmod +x ./quick-sharun.sh
./quick-sharun.sh
#  /usr/bin/prusa-slicer \
#  /usr/bin/OCCTWrapper.so

#ln -s ../lib/bin/OCCTWrapper.so ./AppDir/bin/OCCTWrapper.so
##cp -r /usr/resources ./AppDir/usr/
./quick-sharun.sh --make-appimage

echo "All Done!"