DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGES=$DIR/packages
WORKSPACE=$DIR/workspace
RUNNER_WORKSPACE=/Users/runner/work/mpv-macos-intel/mpv-macos-intel/workspace
export PATH="${WORKSPACE}/bin:$PATH"

#copy all *.dylib to mpv.app
cp -r $PACKAGES/mpv/TOOLS/osxbundle/mpv.app $PACKAGES/mpv/build
cp $PACKAGES/mpv/build/mpv $PACKAGES/mpv/build/mpv.app/Contents/MacOS
ln -s $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv-bundle

mpv_otool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
echo "${mpv_otool[@]}" > $DIR/mpv_otool

#remove rpath definitions towards dev tools
#rpaths_dev_tools=($(otool -l $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep -A2 LC_RPATH | grep path | grep -E "Xcode|CommandLineTools" | awk '{ print $2 }'))
#for path in "${rpaths_dev_tools[@]}"; do
#	install_name_tool -delete_rpath $path
#done


mpv_rpath=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
echo "${mpv_rpath[@]}" > $DIR/mpv_rpath

swift_dylibs_otool=()
for dylib in "${mpv_rpath[@]}"; do
	swift_dylib_otool=($(otool -L $WORKSPACE/lib/$dylib | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
	swift_dylibs_otool+=("${swift_dylib_otool[@]}")
done
swift_dylibs_otool=($(echo "${swift_dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${swift_dylibs_otool[@]}" > $DIR/swift_dylibs_otool

mpv_dylibs_otool=()
for dylib in "${mpv_otool[@]}"; do
	mpv_dylib_otool=($(otool -L $WORKSPACE/lib/$dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
	mpv_dylibs_otool+=("${mpv_dylib_otool[@]}")
done
mpv_dylibs_otool=($(echo "${mpv_dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${mpv_dylibs_otool[@]}" > $DIR/mpv_dylibs_otool

dylibs_otool=()
for dylib in "${mpv_dylibs_otool[@]}"; do
	dylib_otool=($(otool -L $WORKSPACE/lib/$dylib | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
	dylibs_otool+=("${dylib_otool[@]}")
done	
dylibs_otool=($(echo "${dylibs_otool[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${dylibs_otool[@]}" > $DIR/dylibs_otool

all_dylibs=(${mpv_otool[@]} ${mpv_dylibs_otool[@]} ${swift_dylibs_otool[@]} ${dylibs_otool[@]})
all_dylibs=($(echo "${all_dylibs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
echo "${all_dylibs[@]}" > $DIR/all_dylibs

for f in "${all_dylibs[@]}"; do
  find $WORKSPACE/lib -name "$f" -print0 | xargs -0 -I {} cp {} $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib
done

#fix install name path rpath etc.

#remove rpath
install_name_tool -delete_rpath /Library/Developer/Toolchains/swift-4.2.4-RELEASE.xctoolchain/usr/lib/swift/macosx $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv
install_name_tool -delete_rpath $RUNNER_WORKSPACE/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

#add rpath
install_name_tool -add_rpath @executable_path/lib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv

arr_mpv_otool=($(cat $DIR/mpv_otool))
arr_mpv_rpath=($(cat $DIR/mpv_rpath))
arr_all_dylibs=($(cat $DIR/all_dylibs))
arr_swift_dylibs_otool=($(cat $DIR/swift_dylibs_otool))

for dylib in "${arr_mpv_otool[@]}"; do
	install_name_tool -change $RUNNER_WORKSPACE/lib/$dylib @executable_path/lib/$dylib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv;
done

for dylib in "${arr_mpv_rpath[@]}"; do
	install_name_tool -change @rpath/$dylib @executable_path/lib/$dylib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/mpv
done

for dylib in "${arr_all_dylibs[@]}"; do
  install_name_tool -id "@executable_path/lib/$dylib" "$PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$dylib"
	dylib_tool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$dylib | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
	for dylib_dylib in "${dylib_tool[@]}"; do
		install_name_tool -change $RUNNER_WORKSPACE/lib/$dylib_dylib @executable_path/lib/$dylib_dylib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$dylib
  done
	swift_tool=($(otool -L $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$dylib | grep '@rpath' | awk '{ print $1 }' | awk -F '/' '{print $NF}'))
	for dylib_dylib in "${swift_tool[@]}"; do
		install_name_tool -change @rpath/$dylib_dylib @executable_path/lib/$dylib_dylib $PACKAGES/mpv/build/mpv.app/Contents/MacOS/lib/$dylib
  done  
done

