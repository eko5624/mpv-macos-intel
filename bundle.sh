#set -x

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES=$DIR/packages
WORKSPACE=$DIR/workspace
RUNNER_WORKSPACE=/Users/runner/work/mpv-macos-intel/mpv-macos-intel/workspace
SWIFT_PATH=/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx

#fix dylibs install_name  
install_name_tool -change "libvpx.8.dylib" "$WORKSPACE/lib/libvpx.8.dylib" "$WORKSPACE/lib/libavcodec.dylib"
install_name_tool -change "libvpx.8.dylib" "$WORKSPACE/lib/libvpx.8.dylib" "$WORKSPACE/lib/libavdevice.dylib"
install_name_tool -change "libvpx.8.dylib" "$WORKSPACE/lib/libvpx.8.dylib" "$WORKSPACE/lib/libavfilter.dylib"
install_name_tool -change "libvpx.8.dylib" "$WORKSPACE/lib/libvpx.8.dylib" "$WORKSPACE/lib/libavformat.dylib"
install_name_tool -change "/usr/local/opt/little-cms2/lib/liblcms2.2.dylib" "$WORKSPACE/lib/liblcms2.2.dylib" "$WORKSPACE/lib/libjxl.dylib"
install_name_tool -change "build/release/libmujs.dylib" "@executable_path/lib/libmujs.dylib"  "$PACKAGES/mpv/build/mpv"

#copy all *.dylib to mpv.app
cp -r $PACKAGES/mpv/TOOLS/osxbundle/mpv.app $PACKAGES/mpv/build
cp $PACKAGES/mpv/build/mpv $PACKAGES/mpv/build/mpv.app/Contents/MacOS
sudo ln -s $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv-bundle

mpv_otool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
#echo "${mpv_otool[@]}" > $PACKAGES/mpv/build/mpv_otool

mpv_rpath=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))

swift_dylibs_otool=()
for dylib in "${mpv_rpath[@]}"; do
  swift_dylib_otool=($(otool -L $WORKSPACE/lib/$dylib | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
  swift_dylibs_otool+=("${swift_dylib_otool[@]}")
done
swift_dylibs_otool=($(echo "${swift_dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
#echo "${swift_dylibs_otool[@]}" > $PACKAGES/mpv/build/swift_dylibs_otool

mpv_dylibs_otool=()
for dylib in "${mpv_otool[@]}"; do
  mpv_dylib_otool=($(otool -L $WORKSPACE/lib/$dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
  mpv_dylibs_otool+=("${mpv_dylib_otool[@]}")
done
mpv_dylibs_otool=($(echo "${mpv_dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
#echo "${mpv_dylibs_otool[@]}" > $PACKAGES/mpv/build/mpv_dylibs_otool

dylibs_otool=()
for dylib in "${mpv_dylibs_otool[@]}"; do
  dylib_otool=($(otool -L $WORKSPACE/lib/$dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
  dylibs_otool+=("${dylib_otool[@]}")
done	
dylibs_otool=($(echo "${dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
#echo "${dylibs_otool[@]}" > $PACKAGES/mpv/build/dylibs_otool

all_dylibs=(${mpv_otool[@]} ${swift_dylibs_otool[@]} ${mpv_dylibs_otool[@]} ${dylibs_otool[@]})
all_dylibs=($(echo "${all_dylibs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
#echo "${all_dylibs[@]}" > $PACKAGES/mpv/build/all_dylibs

for f in "${all_dylibs[@]}"; do
  if [[ "$(basename $f)" != "libswift"* ]]; then
    find $WORKSPACE/lib -name "$f" -print0 | xargs -0 -I {} cp {} $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib
  else  
    find $SWIFT_PATH -name "$f" -print0 | xargs -0 -I {} cp {} $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib
  fi  
done

#remove rpath
install_name_tool -delete_rpath /Library/Developer/Toolchains/swift-4.2.4-RELEASE.xctoolchain/usr/lib/swift/macosx $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv
install_name_tool -delete_rpath $RUNNER_WORKSPACE/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

#add rpath
install_name_tool -add_rpath @executable_path/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

for dylib in "${mpv_otool[@]}"; do
  install_name_tool -change $RUNNER_WORKSPACE/lib/$dylib @executable_path/lib/$dylib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv;
done

for f in $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/*.dylib; do
  if [[ "$(basename $f)" != "libswift"* ]]; then
    install_name_tool -id "@executable_path/lib/$(basename $f)" "$PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)"
    dylib_tool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f) | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
    for dylib_dylib in "${dylib_tool[@]}"; do
      install_name_tool -change $RUNNER_WORKSPACE/lib/$dylib_dylib @executable_path/lib/$dylib_dylib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)
    done
  fi   
done
