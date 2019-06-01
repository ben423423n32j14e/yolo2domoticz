#/bin/bash

# Requires: apt-get install sshpass

# Script Configuration
uniqueidentifier="001"

# Domoticz Configuration
domoticzserver="192.168.0.5"
domoticzport="443"
domoticzuser="username"
domoticzpass="password"

# Run once
mkdir -p "/tmp/darknet/$uniqueidentifier"

while true; do

# Get output from the data source
output=$(sshpass -p PASSWORD ssh USERNAME@192.168.0.43 /opt/darknet/main.sh "process" "synology" "https://192.168.0.2:5001" "USERNAME" "PASSWORD" "12")

# Object 1 START ----------------------------------------------------------
object="cat"
quantity="1" # For example, trigger when x number or more cats are detected (can be changed to exact, read comments below)
accuracy="70" # Minimum accuracy percent, below this number will be ignored
objecttimeout="3" # Number of cycles before declaring object as missing
domoticzidx="1358" # IDX of the switch in Domoticz
# Filter result for target object
result=$(echo "$output" | grep "$object" | awk '{ print $2 }' | sed 's/[^0-9]*//g' | sed '/^$/d')
# Count number of matching objects
objectcount=$(echo "$result" | grep -v '^$' | wc -l)
# For each target object detected, check if it meets defined accuracy and quantity criteria and increase counter
counter="0"
for item in $result; do if (( $item >= $accuracy )) && (( $objectcount >= $quantity )); then # Note that >= means set quantity or higher == means exact setting (change if needed) counter=$((counter+1)) fi done
counter=$((counter+1))
fi
done
# Check existing state of Domoticz switch
edst=$(curl --max-time 60 -k -s "https://{$domoticzuser}:{$domoticzpass}@{$domoticzserver}:{$domoticzport}/json.htm?type=lightlog&idx={$domoticzidx}" | jq -r ".result[0].Status") # Existing Domoticz Switch State (edst)
# If a target object was identified according to set paramters
if (( "$counter" >= 1 )); then
echo "Detected: $counter $object"
# Update Domoticz if applicable
if [[ "$edst" == "Off" ]]; then
echo "Setting Domoticz switch to On"
curl --max-time 60 -k -s "https://{$domoticzuser}:{$domoticzpass}@{$domoticzserver}:{$domoticzport}/json.htm?type=command&param=switchlight&idx={$domoticzidx}&switchcmd=On"
fi
echo "0" > "/tmp/darknet/${uniqueidentifier}/${object}_history"
else
ticklog=$(cat "/tmp/darknet/${uniqueidentifier}/${object}_history")
tick=$((ticklog+1))
echo "$tick" > "/tmp/darknet/${uniqueidentifier}/${object}_history"
echo "Unable to find object in image: $ticklog"
# Update Domoticz if applicable
if (( "$ticklog" == 5 )); then
echo "Setting Domoticz switch to Off"
curl --max-time 60 -k -s "https://{$domoticzuser}:{$domoticzpass}@{$domoticzserver}:{$domoticzport}/json.htm?type=command&param=switchlight&idx={$domoticzidx}&switchcmd=Off"
fi
fi
# Object 1 END ------------------------------------------------------------

done
