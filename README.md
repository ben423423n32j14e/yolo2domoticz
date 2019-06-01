# yolo2domoticz
Scripts for integrating Yolo object recognition with Domoticz
<BR>
1) Install Yolo with Cuda support into /opt/darknet follow: https://pjreddie.com/darknet/yolo/
2) apt-get install jpeginfo screen wget jq ffmpeg uuid sudo
3) Check you can see the Nvidia card and Cuda version: nvidia-smi
4) Copy main.sh into /opt/darknet

<BR>
  
# How to use main.sh:

main.sh is the script that must be running on the host pc that contains the Nvidia graphics card, Cuda and Darknet software. When started the script starts an instance of Darknet on the Nvidia GPU and keeps it running ready to handle images and display the results.

#### Start the processor

```
/opt/darknet/main.sh "start"
```

#### Stop the processor
  
```
/opt/darknet/main.sh "stop"
```
#### Process an image and display results in terminal
<BR>
Source: Synology Surveillance Station (number at the end is the camera number)
  
```
/opt/darknet/main.sh "process" "synology" "https://192.168.0.2:5001" "username" "password" "4"
```
Source: http or https (example URL is for a Foscam R2)
  
```
/opt/darknet/main.sh "process" "http" "https://192.168.0.63/cgi-bin/CGIProxy.fcgi?cmd=snapPicture2&usr=username&pwd=password"
```
Source: rtsp
  
```
/opt/darknet/main.sh "process" "rtsp" "rtsp://username:password@192.168.0.126/onvif1"
```
#### Sample terminal output:
<BR>
  
```
root@bigcat:/opt/darknet# /opt/darknet/main.sh "process" "synology" "https://192.168.0.2:5001" "username" "password" "4"
Predicted in 0.188455 seconds.
oven: 77%
microwave: 56%
```

#### Script to run main.sh automatically at startup:
eg:
<BR>
nano /etc/init.d/mainsh
<BR>
chmod 755 /etc/init.d/mainsh
<BR>
update-rc.d mainsh defaults
  
```
#!/bin/sh
### BEGIN INIT INFO
# Provides: mainsh
# Required-Start: $network
# Required-Stop: $network
# Default-Start: 2 3 5
# Default-Stop:
# Description: Starts main.sh
### END INIT INFO

case "$1" in
'start')
        sudo -u root /usr/bin/screen -S darknetstartup -d -m bash -c "/opt/darknet/main.sh start"
        ;;
'stop')
        sudo -u root /opt/darknet/main.sh "stop"
        ;;
*)
        echo "Usage: $0 { start | stop }"
        ;;
esac
exit 0
```
#### Using main.sh remotely over SSH:
If you want to get at the data on the host running main.sh from another machine that's running for example Domoticz, apt-get install sshpass, login via ssh at least once manually to accept the certificate then you should be able to use a command similar to below:

```
sshpass -p PASSWORD ssh USERNAME@192.168.0.43 /opt/darknet/main.sh "process" "synology" "https://192.168.0.2:5001" "username" "password" "4"
```
