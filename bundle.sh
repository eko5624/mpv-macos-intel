#note: put bundle.sh into mpv source code directory

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

sudo cp -r $DIR/mpv/TOOLS/osxbundle/mpv.app $DIR/mpv/build
sudo cp $DIR/mpv/build/mpv $DIR/mpv/build/mpv.app/Contents/MacOS
pushd $DIR/mpv/build/mpv.app/Contents/MacOS
sudo ln -s mpv mpv-bundle
popd

mpv_deps=($(otool -L $DIR/mpv/build/mpv.app/Contents/MacOS/mpv | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
for i in "${mpv_deps[@]}"; do
  echo $i >> $PACKAGES/mpv/build/mpv_deps.txt
done

get_deps() {
  local deps=$(otool -L $1 | grep -e '\t' | grep -Ev "\/usr\/lib|\/System|@rpath" | awk 'NR>1 {print $1}')
  for dep in $deps; do
    echo $dep
    get_deps $dep
  done
}
lib_deps=$(get_deps "$DIR/mpv/build/mpv.app/Contents/MacOS/mpv" | sort -u)
echo "${lib_deps[@]}" > $DIR/mpv/build/lib_deps.txt

all_deps=(${mpv_deps[@]} ${lib_deps[@]})
all_deps=($(echo "${all_deps[@]}" | tr ' ' '\n' | sort -u))
for i in "${all_deps[@]}"; do
  echo $i >> $DIR/mpv/build/all_deps.txt
done

for f in "${all_deps[@]}"; do
  if [[ "$f" != "@loader_path"* ]]; then
    sudo cp $f $DIR/mpv/build/mpv.app/Contents/MacOS/lib
  fi
done

#removing rpath definitions towards dev tools
rpaths=($(otool -l $DIR/mpv/build/mpv.app/Contents/MacOS/mpv | grep -A2 LC_RPATH | grep path | awk '{ print $2 }'))
for f in "${rpaths[@]}"; do
  sudo install_name_tool -delete_rpath $f $DIR/mpv/build/mpv.app/Contents/MacOS/mpv
done

#setting additional rpath for swift libraries
sudo install_name_tool -add_rpath @executable_path/lib $DIR/mpv/build/mpv.app/Contents/MacOS/mpv

for dylib in "${mpv_deps[@]}"; do
  sudo install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $DIR/mpv/build/mpv.app/Contents/MacOS/mpv
done

for f in $DIR/mpv/build/mpv.app/Contents/MacOS/lib/*.dylib; do
  sudo install_name_tool -id "@executable_path/lib/$(basename $f)" "$DIR/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)"
  dylib_tool=($(otool -L $f | grep -Ev "\/usr\/lib|\/System|@rpath" | awk '{ print $1 }'))
  for dylib in "${dylib_tool[@]}"; do
    if [[ "${#dylib_tool[@]}" > 1 ]]; then
      sudo install_name_tool -change $dylib @executable_path/lib/$(basename $dylib) $DIR/mpv/build/mpv.app/Contents/MacOS/lib/$(basename $f)
    fi  
  done 
done
