angles=(0.001 2.5 5 7.5 10 12 15 20 25 30)
./write_mesh_properties.sh

for angle in "${angles[@]}"; do
    cp -r . /tmp/airfoil_$angle
    SILENT=1 /tmp/airfoil_$angle/run_at_angle.sh $angle &
done
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
wait
name=$(jq '.name' config.json | tr -d '"')
turbulence_model=$(jq '.turbulence_model' config.json | tr -d '"')
mkdir -p results/$turbulence_model
dir="results/$turbulence_model/$name"
rm -r $dir
mkdir $dir
cp config.json $dir/config.json
for angle in "${angles[@]}"; do
    echo -n -e "$angle\t\t" >> $dir/allResults.dat
    tail -n 1 /tmp/airfoil_$angle/postProcessing/calcForceCoefficients/0/forceCoeffs.dat >> $dir/allResults.dat
done