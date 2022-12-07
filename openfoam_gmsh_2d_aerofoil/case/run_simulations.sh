rm allResults.dat
angles=(0.1 5 10 15 20)
for angle in "${angles[@]}"; do
    SILENT=1 ./run_at_angle.sh $angle
    echo "$angle   " >> allResults.dat
    tail -n 1 postProcessing/calcForceCoefficients/0/forceCoeffs.dat >> allResults.dat
done
