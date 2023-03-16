#set -x

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES=$DIR/packages
WORKSPACE=$DIR/workspace
SWIFT_PATH=/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx

#copy all *.dylib to mpv.app
cp -r $PACKAGES/mpv/TOOLS/osxbundle/mpv.app $PACKAGES/mpv/build
cp $PACKAGES/mpv/build/mpv $PACKAGES/mpv/build/mpv.app/Contents/MacOS
pushd $PACKAGES/mpv/build/mpv.app/Contents/MacOS
ln -s mpv mpv-bundle
popd

mpv_otool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
echo "${mpv_otool[@]}" > $PACKAGES/mpv/build/mpv_otool

mpv_rpath=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))

swift_dylibs_otool=()
for dylib in "${mpv_rpath[@]}"; do
  swift_dylib_otool=($(otool -L $SWIFT_PATH/$dylib | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
  swift_dylibs_otool+=("${swift_dylib_otool[@]}")
done
swift_dylibs_otool=($(echo "${swift_dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${swift_dylibs_otool[@]}" > $PACKAGES/mpv/build/swift_dylibs_otool

mpv_dylibs_otool=()
for dylib in "${mpv_otool[@]}"; do
  mpv_dylib_otool=($(otool -L $dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
  mpv_dylibs_otool+=("${mpv_dylib_otool[@]}")
done
mpv_dylibs_otool=($(echo "${mpv_dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${mpv_dylibs_otool[@]}" > $PACKAGES/mpv/build/mpv_dylibs_otool

dylibs_otool=()
for dylib in "${mpv_dylibs_otool[@]}"; do
  dylib_otool=($(otool -L $dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
  dylibs_otool+=("${dylib_otool[@]}")
done	
dylibs_otool=($(echo "${dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

for dylib in "${dylibs_otool[@]}"; do
  dylib_dylib_otool=($(otool -L $dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
  if [[ "${#dylib_dylib_otool[@]}" > 1 ]]; then
    dylibs_otool+=("${dylib_dylib_otool[@]}")
  fi  
done	
dylibs_otool=($(echo "${dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${dylibs_otool[@]}" > $PACKAGES/mpv/build/dylibs_otool

all_dylibs=(${mpv_otool[@]} ${swift_dylibs_otool[@]} ${mpv_dylibs_otool[@]} ${dylibs_otool[@]})
all_dylibs=($(echo "${all_dylibs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${all_dylibs[@]}" > $PACKAGES/mpv/build/all_dylibs

for f in "${all_dylibs[@]}"; do
  if [[ "$(basename $f)" != "libswift"* ]]; then
    find $WORKSPACE/lib -name "$(basename $f)" -print0 | xargs -0 -I {} cp {} $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib
  else  
    find $SWIFT_PATH -name "$(basename $f)" -print0 | xargs -0 -I {} cp {} $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib
  fi  
done

#removing rpath definitions towards dev tools
rpaths=($(otool -l $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep -A2 LC_RPATH | grep path | awk '{ print $2 }'))
for f in "${rpaths[@]}"; do
  sudo install_name_tool -delete_rpath $f $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv
done

#setting additional rpath for swift libraries
install_name_tool -add_rpath @executable_path/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

for dylib in "${mpv_otool[@]}"; do
  sudo install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv
done

for f in $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/*.dylib; do
  if [[ "$(basename $f)" != "libswift"* ]]; then
    sudo install_name_tool -id "@executable_path/lib/$(basename $f)" "$PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)"
    dylib_tool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f) | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
    for dylib in "${dylib_tool[@]}"; do
      sudo install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)
    done
  fi   
done
