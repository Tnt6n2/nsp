# find base and update NSPs
basensp=$(ls -S *.nsp | head -1)
updatensp=$(ls -Sr *.nsp | head -1)

# clone and build hactool and hacpack
git clone https://github.com/SciresM/hactool
mv hactool hactoolsrc
cd hactoolsrc
mv config.mk.template config.mk
make
mv hactool ..
cd ..
rm -rf hactoolsrc

git clone https://github.com/The-4n/hacPack
mv hacPack hacpacksrc
cd hacpacksrc
mv config.mk.template config.mk
make
mv hacpack ..
cd ..
rm -rf hacpacksrc

mkdir -p ~/.switch
cp prod.keys ~/.switch
touch ~/.switch/title.keys

mkdir temp hactool_out
cd hactool_out

# derive title keys from base and update NSPs
derivekey () {
	title=$(xxd *.tik | grep -oP -m 1 "(?<=2a0: ).{39}" | sed 's/ //g')
	key=$(xxd *.tik | grep -oP -m 1 "(?<=180: ).{39}" | sed 's/ //g')
	sed -i "/$title=$key/d" ~/.switch/title.keys
	echo $title=$key >> ~/.switch/title.keys
}
../hactool -t pfs0 "../$basensp" --outdir .
derivekey
rm *
../hactool -t pfs0 "../$updatensp" --outdir .
derivekey
rm *

# extract base NSP and move program NCA to temp dir
../hactool -t pfs0 "../$basensp" --outdir .
for i in *.nca
do
	type=$(../hactool $i | grep -oP "(?<=Content Type:\s{23}).*")
	if [ $type == "Program" ]; then
		basenca=$i
		mv $i ../temp
	fi
done
rm *

# extract update NSP and move program & control NCAs to temp dir
../hactool -t pfs0 "../$updatensp" --outdir .
for i in *.nca
do
	type=$(../hactool $i | grep -oP "(?<=Content Type:\s{23}).*")
	if [ $type == "Program" ]; then
		updatenca=$i
		mv $i ../temp
	elif [ $type == "Control" ]; then
		controlnca=$i
		mv $i ../temp
	fi
done
rm *

cd ..
rm -rf hactool_out

mv hactool temp/
mv hacpack temp/
cd temp

# parse Title ID from base program NCA
titleid=$(./hactool $basenca | grep -oP "(?<=Title ID:\s{27}).*")

# extract base and update NCAs into romfs end exefs
mkdir exefs romfs
./hactool --basenca="$basenca" $updatenca --romfsdir="romfs" --exefsdir="exefs"
rm $basenca $updatenca
cd ..

mv temp/nsp/$titleid.nsp ./$titleid[patched].nsp

rm -rf temp
