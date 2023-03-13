#set -x

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES=$DIR/packages
WORKSPACE=$DIR/workspace
RUNNER_WORKSPACE=/Users/runner/work/mpv-macos-intel/mpv-macos-intel/workspace

#copy all *.dylib to mpv.app
cp -r $PACKAGES/mpv/TOOLS/osxbundle/mpv.app $PACKAGES/mpv/build
cp $PACKAGES/mpv/build/mpv $PACKAGES/mpv/build/mpv.app/Contents/MacOS
pushd $PACKAGES/mpv/build/mpv.app/Contents/MacOS
ln -s mpv mpv-bundle
popd

mpv_otool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
#echo "${mpv_otool[@]}" > $PACKAGES/mpv/build/mpv_otool

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

all_dylibs=(${mpv_otool[@]} ${mpv_dylibs_otool[@]} ${dylibs_otool[@]})
all_dylibs=($(echo "${all_dylibs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
#echo "${all_dylibs[@]}" > $PACKAGES/mpv/build/all_dylibs

for f in "${all_dylibs[@]}"; do
  find $WORKSPACE/lib -name "$f" -print0 | xargs -0 -I {} cp {} $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib
done

#removing lib rpath
install_name_tool -delete_rpath $RUNNER_WORKSPACE/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

#setting additional rpath for swift libraries
install_name_tool -add_rpath @executable_path/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

for dylib in "${mpv_otool[@]}"; do
  install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv
done

for f in $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/*.dylib; do
  install_name_tool -id "@executable_path/lib/$(basename $f)" "$PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)"
  dylib_tool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f) | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
  for dylib in "${dylib_tool[@]}"; do
    install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)
  done 
done
