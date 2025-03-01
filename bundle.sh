#!/bin/sh

set -x
PACKAGE=PrusaSlicer
DESKTOP=/usr/resources/applications/PrusaSlicer.desktop
ICON=/usr/resources/icons/PrusaSlicer.png

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1

APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
UPINFO="gh-releases-zsync|$(echo $GITHUB_REPOSITORY | tr '/' '|')|continuous|*$ARCH.AppImage.zsync"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"

# Prepare AppDir
mkdir -p ./"$PACKAGE"/AppDir/shared/lib \
  ./"$PACKAGE"/AppDir/usr/share/applications \
  ./"$PACKAGE"/AppDir/etc
cd ./"$PACKAGE"/AppDir

cp -r /usr/resources     ./usr/

cp $DESKTOP              ./usr/share/applications
cp $DESKTOP              ./
cp /"$ICON"              ./

ln -s ./usr/share        ./share
ln -s ./usr/resources    ./resources
ln -s ./shared/lib       ./lib

# DEPLOY GDK # FIXME: Automate
echo "Deploying gdk..."
GDK_PATH="$(find /usr/lib -type d -regex ".*/gdk-pixbuf-2.0" -print -quit)"
cp -rv "$GDK_PATH" ./shared/lib
echo "Deploying gdk deps..."
find ./shared/lib/gdk-pixbuf-2.0 -type f -name '*.so*' -exec ldd {} \; \
  | awk -F"[> ]" '{print $4}' | xargs -I {} cp -vn {} ./shared/lib
find ./shared/lib -type f -regex '.*gdk.*loaders.cache' \
  -exec sed -i 's|/.*lib.*/gdk-pixbuf.*/.*/loaders/||g' {} \;

# ADD LIBRARIES
rm ./lib4bin || true
wget "$LIB4BN" -O ./lib4bin
chmod +x ./lib4bin
xvfb-run -- ./lib4bin -p -v -r -e /usr/bin/prusa-slicer
rm -f ./lib4bin
find /usr/bin /usr/lib -type f -name 'OCCTWrapper.so' -exec cp -vn {} ./bin \;
find /usr/lib -type f -name '*libnss*.so*' -exec cp -vn {} ./shared/lib \;

# find ./shared -type f -exec strip -s -R .comment --strip-unneeded {} ';'
find ./shared -type f -exec strip {} \; || true

# Copy WebKitNetworkProcess binaries and wrap them in sharun; FIXME: Automate
mkdir -p ./shared/lib/webkit2gtk-4.1
cp -r /usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/* ./shared/bin/
( cd ./shared/lib/webkit2gtk-4.1
  ln -s ../../../sharun ./WebKitWebProcess
  ln -s ../../../sharun ./WebKitNetworkProcess
  ln -s ../../../sharun ./MiniBrowser
)
find ./shared/lib -name 'libwebkit*' -exec sed -i 's|/usr|././|g' {} \;
ln -s ./ ./shared/lib/x86_64-linux-gnu
mkdir -p lib/x86_64-linux-gnu/webkit2gtk-4.1/injected-bundle/
cd lib/x86_64-linux-gnu/webkit2gtk-4.1/injected-bundle/
ln -s ../../../../shared/bin/injected-bundle/libwebkit2gtkinjectedbundle.so .
cd -
# Try to fix "TSL/SSL support not available"
mkdir -p ./lib/x86_64-linux-gnu/gio
cp -r /usr/lib/x86_64-linux-gnu/gio/modules ./lib/x86_64-linux-gnu/gio/
cp $(ldd ./lib/x86_64-linux-gnu/gio/modules/*.so |cut -d ">" -f 2 | cut -d " " -f 2 | sort | uniq) ./shared/lib/ 2>/dev/null || true # FIXME: Deploy dependencies properly

# Copy DRI and glvnd, FIXME: Should happen automatically and ther dependencies shoud also be deployed
cp -L /usr/lib/x86_64-linux-gnu/{libGLX_indirect.so.0,libGLX_mesa.so.0,libxcb-dri2.so.0,libxcb-dri3.so.0,libxcb-glx.so.0,libxcb-present.so.0,libxcb-sync.so.1,libxcb-xfixes.so.0,libxshmfence.so.1,libGLdispatch.so.0,libdrm.so.2,libgbm.so.1,libvulkan.so.1} ./shared/lib/
cp -r /usr/share/glvnd   ./usr/share/ # FIXME: Shouldn't it be ./share/?
cp -r /usr/lib/x86_64-linux-gnu/dri ./shared/lib/ # May need environment variable LIBGL_DRIVERS_PATH at runtime since '\$${ORIGIN}' in RPATH is wrong?
cp $(ldd ./shared/lib/dri/*.so |cut -d ">" -f 2 | cut -d " " -f 2 | sort | uniq) ./shared/lib/ 2>/dev/null || true # FIXME: Deploy dependencies properly
cp $(ldd ./shared/lib/*.so |cut -d ">" -f 2 | cut -d " " -f 2 | sort | uniq) ./shared/lib/ 2>/dev/null || true # FIXME: Deploy dependencies properly

# Create environment
cat > .env <<\EOF
SHARUN_WORKING_DIR=${SHARUN_DIR}
LIBGL_DRIVERS_PATH=${SHARUN_DIR}/shared/lib/dri
GIO_MODULE_DIR=${SHARUN_DIR}/lib/x86_64-linux-gnu/gio/modules/
GSETTINGS_BACKEND=memory
unset LD_LIBRARY_PATH
unset LD_PRELOAD
EOF
# NOTE: sharun should already set GIO_MODULE_DIR automatically
# LOCPATH=${SHARUN_DIR}/lib/locale:${SHARUN_DIR}/share/locale # This makes PrusaSlicer fail

# Copy additional libraries
# Prepare sharun
rm sharun || true
wget -c https://github.com/VHSgunzo/sharun/releases/download/v0.1.8/sharun-x86_64-upx -O ./sharun || true
chmod +x ./sharun
ln ./sharun ./AppRun
./sharun -g || true # FIXME

# Do we also need the __EGL_VENDOR_LIBRARY_DIRS environment variable?

# NixOS does not have /usr/lib/locale nor /usr/share/locale, which PrusaSlicer expects
cp -r /usr/lib/locale ./lib/
sed -i -e 's|/usr/lib/locale|././/lib/locale|g' ./bin/prusa-slicer # Since we cannot get LOCPATH to work properly
mkdir -p ./share
cp -r /usr/share/locale ./share/
sed -i -e 's|/usr/share/locale|././/share/locale|g' ./shared/lib/libc.so.6 # Since we cannot get LOCPATH to work properly
sed -i -e 's|/usr/lib/locale|././/lib/locale|g' ./shared/lib/libc.so.6  # Since we cannot get LOCPATH to work properly

# Without this, the save dialog does not work
mkdir -p ./share/glib-2.0/
cp -r /usr/share/glib-2.0/schemas ./share/glib-2.0/

# MAKE APPIMAGE WITH STATIC RUNTIME
cd ..
rm ./appimagetool || true
wget -q "$APPIMAGETOOL" -O ./appimagetool
chmod +x ./appimagetool

./appimagetool \
  --comp zstd \
  --mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
  -n -u "$UPINFO" "$PWD"/AppDir "$PWD"/"$PACKAGE"-"$VERSION"-"$ARCH".AppImage

mv ./*.AppImage* ../
cd ..
rm -rf ./"$PACKAGE"
echo "All Done!"
