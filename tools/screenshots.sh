#!/bin/bash

# TODO: check for adb
# TODO: check for AVD
# TODO: check for imagemagick

. tokendeeplink.sh

if [ -z "$TOKEN_DEEPLINK" ]; then
	echo "TOKEN_DEEPLINK variable is not set correctly. Make sure the file tokendeeplink.sh is present and properly sets the variable."; 
	exit 1
fi

if ! [[ "$TOKEN_DEEPLINK" =~ ^wordpress:\/\/magic-login\?token=* ]]; then
	echo "TOKEN_DEEPLINK format is invalid.";
	exit 1
fi;

AVD=Nexus_5X_API_25

APP_HEIGHT=1388
NAV_HEIGHT=96
SKIN_WIDTH=840
SKIN_HEIGHT=$(($APP_HEIGHT+$NAV_HEIGHT))
SKIN=$SKIN_WIDTH'x'$SKIN_HEIGHT
LCD_DPI=320

APK=../WordPress/build/outputs/apk/WordPress-wasabi-debug.apk
PKG_RELEASE=org.wordpress.android
PKG_DEBUG=org.wordpress.android.beta
ACTIVITY_LAUNCH=org.wordpress.android.ui.WPLaunchActivity

COORDS_MY_SITE="100 100"
COORDS_READER="300 100"
COORDS_ME="500 100"
COORDS_ME_GRAVATAR_POPUP="650 300"
COORDS_NOTIFS="700 100"

ADB_PARAMS="-e"

PHONE_TEMPLATE=android-phone-template2.png
PHONE_OFFSET="+121+532"
TAB7_TEMPLATE=android-tab7-template2.png
TAB7_OFFSET="+145+552"
TAB10_TEMPLATE=android-tab10-template2.png
TAB10_OFFSET="+148+622"

#echo $AVD
#echo '\n'

#echo $SKIN
#echo '\n'

#echo $LCD_DPI

function start_emu {
  echo -n Starting emulator... 
  /Applications/android/sdk/tools/emulator -avd $AVD -skin $SKIN -qemu -lcd-density $LCD_DPI &>/dev/null &
  echo Done
}

function wait_emu {
  echo -n Waiting for device boot... 
  adb $ADB_PARAMS wait-for-device

  # poll and wait until device has booted
  A=$(adb $ADB_PARAMS shell getprop sys.boot_completed | tr -d '\r')
  while [ "$A" != "1" ]; do
    sleep 2
    A=$(adb $ADB_PARAMS shell getprop sys.boot_completed | tr -d '\r')
  done
  echo Done
}

function uninstall {
  echo -n Uninstalling any previous app instances... 
  adb $ADB_PARAMS shell pm uninstall $PKG_DEBUG &>/dev/null
  echo Done
}

function install {
  echo -n Installing app... 
  adb $ADB_PARAMS install -r $APK &>/dev/null
  echo Done
}

function login {
  echo -n Logging in via magiclink... 
  adb $ADB_PARAMS shell am start -W -a android.intent.action.VIEW -d $TOKEN_DEEPLINK $PKG_DEBUG &>/dev/null
  echo Done
}

function start_app {
  echo -n Starting app... 
  adb $ADB_PARAMS shell am start -n $PKG_DEBUG/$ACTIVITY_LAUNCH &>/dev/null
  echo Done
}

function kill_app {
  echo -n Killing the app...
  adb $ADB_PARAMS shell am force-stop $PKG_DEBUG &>/dev/null
  echo Done
}

function tap_on {
  echo -n Tapping on $1x$2...
  adb $ADB_PARAMS shell input tap $1 $2 &>/dev/null
  echo Done
}

function wait() {
  echo -n Waiting for $1 seconds...
  sleep $1
  echo Done
}

function screenshot() {
  echo -n Taking screenshot with name $1...
  adb $ADB_PARAMS shell screencap -p /sdcard/$1.png &>/dev/null
  echo -n  pulling the file...
  adb $ADB_PARAMS pull /sdcard/$1.png ./$1.png &>/dev/null
  echo Done
}

function produce() {
  screenshot $1
  magick $1.png -crop 0x$APP_HEIGHT+0+0 $1_cropped.png
  template=$2_TEMPLATE
  offset=$2_OFFSET
  magick ${!template} $1_cropped.png -geometry ${!offset} -composite $1_comp1.png
}

function locale() {
  echo -n Preparing to set locale...
  adb $ADB_PARAMS root &>/dev/null
  echo Done
  echo -n Setting locale to $1...
  adb $ADB_PARAMS shell "setprop ro.product.locale $1; setprop persist.sys.locale $1; stop; sleep 5; start" &>/dev/null
	wait 10
	wait_emu
	wait 10
}

start_emu
wait_emu
uninstall
install
login

wait 5 # wait for app to finish logging in
kill_app # kill the app so when restarting we don't have any first-time launch effects like promo dialogs and such

start_app
wait 5 # wait for app to finish start up

kill_app # kill the app so when restarting we don't have any first-time launch effects like promo dialogs and such

for device in PHONE #TAB7 TAB10
do
  for loc in en-US #el-GR it-IT
  do
    PREFIX=wpandroid_"$device"_"$loc"

    locale $loc

    start_app
    wait 3

    tap_on $COORDS_MY_SITE
    wait 2
    produce "$PREFIX"_mysites $device
  
    tap_on $COORDS_READER
    wait 10 # wait for reader to refresh
    screenshot "$PREFIX"_reader

    tap_on $COORDS_ME
    wait 2
    tap_on $COORDS_ME_GRAVATAR_POPUP # dismiss the Gravatar change popup
    wait 5
    screenshot "$PREFIX"_me

    tap_on $COORDS_NOTIFS
    wait 5
    screenshot "$PREFIX"_notifs
  done
done

