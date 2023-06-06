#!/usr/bin/env bash

PUBLIC_KEY="$1"

function print_error_message {
    echo -e "\e[31m$1\e[0m"
}

function show_use() {
    echo "Invalid arguments"
    echo "Usage: $0 'public_key' "
    exit 1
}

if [ -z "$REMOTE_IP" ]; then show_use; fi

if [ $# -ne 1 ]; then show_use; fi


if ! command -v adb >/dev/null 2>&1; then
    print_error_message "Can't find adb, make sure you have installed it and added to PATH"
    exit 1
fi

echo -e "\nConnect your phone to your PC"
echo "You need to previously install 'MagiskSSH' by D4rCM4rC"
echo -n "Make sure you have USB debugging enabled. Press enter to continue..."
read -n1

if ! timeout 30 adb wait-for-device; then
    print_error_message "Failed to connect to device"
    exit 1
fi

adb shell "su -c 'echo \"$PUBLIC_KEY\" > /data/ssh/root/.ssh/authorized_keys; chmod 600 /data/ssh/root/.ssh/authorized_keys'"

while true; do
    read -rp "Do you want to preserve the public key if the module is uninstalled? (y/n) " yn
    case $yn in
        [Yy]* ) adb shell "su -c 'touch /data/ssh/KEEP_ON_UNINSTALL'"; break;;
        [Nn]* ) break;;
        * ) print_error_message "Invalid choice. Please try again.";;
    esac
done
