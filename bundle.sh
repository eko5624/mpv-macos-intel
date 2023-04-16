#!/bin/bash
set -x

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

get_deps() {
  local deps=$(otool -L $1 | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk 'NR>1 {print $1}')
  for dep in $deps; do
    echo $dep
    get_deps $dep
  done
}
mpv_deps=$(get_deps "$PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv" | sort -u)

mpv_rpath=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
swift_deps=()
for dylib in "${mpv_rpath[@]}"; do
  swift_dep=($(otool -L $SWIFT_PATH/$dylib | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
  swift_deps+=("${swift_dep[@]}")
done
swift_deps=($(echo "${swift_deps[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${swift_deps[@]}" > $PACKAGES/mpv/build/swift_deps

all_deps=(${mpv_deps[@]} ${swift_deps[@]})
all_deps=($(echo "${all_deps[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${all_deps[@]}" > $PACKAGES/mpv/build/all_deps

for f in "${all_deps[@]}"; do
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
    dylib_tool=($(otool -L $f | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
    for dylib in "${dylib_tool[@]}"; do
      if [[ "${#dylib_tool[@]}" > 1 ]]; then
        sudo install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)
      fi  
    done
  fi   
done
