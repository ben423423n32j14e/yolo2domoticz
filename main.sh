#!/bin/bash

# Requirements: apt-get install jpeginfo screen wget jq ffmpeg uuid sudo

# Configuration
darknetpath='/opt/darknet'
productionmode='no' # If set to yes the watchdog will automatically restart darknet if no data has been processed for 3 minutes (assumes an unknown fault has occured).

# Other
uuid=$(uuid)

# Start Darknet Screen session
if [[ $1 == 'start' ]]; then
sudo -u root /usr/bin/screen -ls darknetbg | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read x; do screen -XS $x quit; done

# Start the watchdog (split multi-line)
if ! screen -list | grep -q "darknetwatchdog"; then
echo "Starting darknetwatchdog..."
sudo -u root /usr/bin/screen -S darknetwatchdog -d -m bash -c "while true; do sleep 60; if pgrep -fl $darknetpath/darknet | grep -Evq 'screen|bash'; then echo \$(date +%T) 'Darknet is already running'; \
else echo \$(date +%T) 'Watchdog is attempting to restart Darknet...' ; sudo -u root /usr/bin/screen -S darknetrestart -d -m timeout 55 $darknetpath/main.sh 'start'; fi; \
if (cat /tmp/darknet/darknetoutput | grep -q 'wait1'); then timesincemod=$(echo $(($(date +%s) - $(date +%s -r /tmp/darknet/darknetoutput)))); if (($timesincemod > 60)); then echo 'ready1' >/tmp/darknet/darknetoutput; fi; fi; \
find /tmp/darknet/*.jpeg -mmin +1 -type f -delete ; if (echo $productionmode | grep -q 'yes'); then if (find /tmp/darknet/darknetoutput -mmin +3 -type f | grep -q '/tmp/darknet/darknetoutput'); then echo \$(date +%T) 'Darknet has not processed data within timeout attempting to restart...' ; sudo -u root /usr/bin/screen -S darknetrestart -d -m timeout 55 $darknetpath/main.sh 'start' ; fi; fi; done"
fi

mkdir -p "/tmp/darknet"
if ! grep -qs /tmp/darknet /proc/mounts; then mount -t tmpfs tmpfs /tmp/darknet >/dev/null 2>&1; fi
echo "wait1" >/tmp/darknet/darknetoutput
rm -rf "$darknetpath/predictions.jpg"
ln -sf "/tmp/darknet/predictions.jpg" "$darknetpath/predictions.jpg"
sudo -u root /usr/bin/screen -S darknetbg -d -m ${darknetpath}/main.sh bgstart
sleep 0.1
until [[ $(cat "/tmp/darknet/darknetoutput" | grep "Enter Image Path:") == *"Enter Image Path:"* ]];do
echo $(date +%T) "Starting darknetbg..."
sleep 3
done
echo "ready1" >/tmp/darknet/darknetoutput
fi

# Stop Darknet Screen session
if [[ $1 == 'stop' ]]; then
echo "wait1" >/tmp/darknet/darknetoutput
echo $(date +%T) "Stopping darknetbg..."
sudo -u root /usr/bin/screen -ls darknetbg | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read x; do screen -XS $x quit; done
sudo -u root /usr/bin/screen -ls darknetwatchdog | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read x; do screen -XS $x quit; done
sudo -u root /usr/bin/screen -ls darknetrestart | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read x; do screen -XS $x quit; done
sudo -u root /usr/bin/screen -ls darknetstartup | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read x; do screen -XS $x quit; done
fi

# Contents of darknetbg screen session
if [[ $1 == 'bgstart' ]]; then
mkdir -p /tmp/darknet
cd $darknetpath
sudo -u root bash -c "export PATH=/usr/local/cuda-10.1/bin${PATH:+:${PATH}} ; \
export LD_LIBRARY_PATH=/usr/local/cuda-10.1/lib64:$LD_LIBRARY_PATH  ; \
${darknetpath}/darknet detect ${darknetpath}/cfg/yolov3.cfg ${darknetpath}/yolov3.weights" >>/tmp/darknet/darknetoutput
fi

# Get image
if [[ $1 == "process" ]]; then
rm -rf "/tmp/darknet/source{$uuid}.jpeg"
if [[ $2 == "http" ]]; then # Get image via HTTP or HTTPS
wget -q --timeout=5 --tries=1 --no-check-certificate -O "/tmp/darknet/source{$uuid}.jpeg" "$3"
elif [[ $2 == "rtsp" ]]; then # Get image from rtsp stream
touch "/tmp/darknet/source{$uuid}.jpeg"
ffmpeg -timelimit 10 -stimeout 10000000 -y -i "$3" -vframes 1 "/tmp/darknet/source{$uuid}.jpeg" >/dev/null 2>&1
elif [[ $2 == "synology" ]]; then # Get image from Synology Surveillance Station
cookiename=$(echo -n $3 | md5sum)
if [[ $(wget -q --timeout=5 --tries=1 --no-check-certificate --server-response --load-cookies /tmp/darknet/cookiename.txt -O- "$3/webapi/entry.cgi?api=SYNO.SurveillanceStation.Camera&method=GetSnapshot&version=3&cameraId=$6&preview=true" -O "/tmp/darknet/source{$uuid}.jpeg" 2>&1 | grep "Content-Type: image/jpeg" | sed -e 's/^[ \t]*//') != "Content-Type: image/jpeg" ]]; then
wget -q --timeout=5 --tries=1 --no-check-certificate --keep-session-cookies --save-cookies /tmp/darknet/cookiename.txt -O- "$3/webapi/auth.cgi?api=SYNO.API.Auth&method=Login&version=3&session=SurveillanceStation&account=$4&passwd=$5" >/dev/null 2>&1 # Login
wget -q --timeout=5 --tries=1 --no-check-certificate --load-cookies /tmp/darknet/cookiename.txt -O- "$3/webapi/entry.cgi?api=SYNO.SurveillanceStation.Camera&method=GetSnapshot&version=3&cameraId=$6&preview=true" -O "/tmp/darknet/source{$uuid}.jpeg" >/dev/null 2>&1 # Request image
fi
fi
# Check image integrity
if [[ $(timeout 15 jpeginfo -c "/tmp/darknet/source{$uuid}.jpeg" | grep -E "WARNING|ERROR|can't open") ]]; then
echo "Problem with source or image, unable to process"
else
# Process image
while grep -q "wait1" /tmp/darknet/darknetoutput ;do # Stopped or waiting for another job to finish
sleep $(echo 0.$(shuf -i100-150 -n1))
done
echo "wait1" >/tmp/darknet/darknetoutput
if >/dev/null pgrep -f /opt/darknet/darknet; then
sudo -u root screen -S darknetbg -p 0 -X stuff "/tmp/darknet/source{$uuid}.jpeg^M"
# Display results
timeout 10 bash -c -- "while ! grep -q $uuid /tmp/darknet/darknetoutput ;do sleep 0.1; done"
rm -rf "/tmp/darknet/source{$uuid}.jpeg" # Delete source image
result=$(if grep -q $uuid /tmp/darknet/darknetoutput; then cat /tmp/darknet/darknetoutput | awk '!/empty|ready1|wait1|Enter Image Path:/' | sed "s/\/tmp\/darknet\/source{$uuid}.jpeg: //g"; fi)
echo "ready1" >/tmp/darknet/darknetoutput
echo "$result"
else
echo "Darknet is not running"
fi
fi
fi
