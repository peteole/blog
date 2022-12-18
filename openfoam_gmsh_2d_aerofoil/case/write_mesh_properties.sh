cells=$(checkMesh | grep cells: | grep -o -E '[0-9]+')
./set_config_property.sh cells $cells
maxAspectRatio=$(checkMesh | grep "Max aspect ratio =" | grep -o -E '[0-9]+.[0-9]+')
./set_config_property.sh maxAspectRatio $maxAspectRatio

turbulence_model=$(foamDictionary constant/momentumTransport -entry RAS/model -value)
./set_config_property.sh turbulence_model $turbulence_model