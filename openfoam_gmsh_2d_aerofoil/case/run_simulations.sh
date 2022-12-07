rm allResults.dat
#angles=(0.001 2.5 5 7.5 10 12.5 15 17.5 20 22.5 25)
angles=(0.001 5 10 15 20 25 30 35)
for angle in "${angles[@]}"; do
    SILENT=1 ./run_at_angle.sh $angle
    echo -n -e "$angle\t\t" >> allResults.dat
    tail -n 1 postProcessing/calcForceCoefficients/0/forceCoeffs.dat >> allResults.dat
done
