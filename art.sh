#!/usr/bin/env bash

function print_error_message {
    echo -e "\e[31m$1\e[0m"
}

function show_use() {
    echo "Invalid arguments"
    echo "Usage: $0 <android_ip> "
    exit 1
}

function check_ssh_connection {
    ssh -q -i "${KEY_LOCATION}" "${REMOTE_HOST}" true
    return $?
}

function show_menu {
    echo -e "\n"
    echo "╭─────────────────────────────────────────────╮"
    echo "│               Choose an option:             │"
    echo "├─────────────────────────────────────────────┤"
    echo "│ 1. Internal Storage                         │"
    echo "│ 2. Whatsapp                                 │"
    echo "│ 3. SwiftBackup                              │"
    echo "│ 4. Exit                                     │"
    echo "╰─────────────────────────────────────────────╯"
}

function confirm_action {
    echo -e "\n"
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│                          WARNING                         │"
    echo "├──────────────────────────────────────────────────────────┤"
    echo "│  This action cannot be undone. Are you sure you want to  │"
    echo "│  proceed?                                                │"
    echo "╰──────────────────────────────────────────────────────────╯"

    read -rp "Enter (y) to confirm or (n) to cancel: " choice
    echo -e "\n"

    case "$choice" in
    y | Y)
        return 0
        ;;
    n | N)
        return 1
        ;;
    *)
        print_error_message "Invalid choice. Please try again."
        confirm_action
        ;;
    esac
}

#####################################################################################################################

#TODO
#LOG_FILE=rsync.log
#rsync -avzP --info=stats2 --delete -e "ssh -p 5777 -i /home/username/.ssh/id_ed25519" "${source}" "${destination}" > "${LOG_FILE}"

if [ ! -f .env ]; then
    print_error_message "Error: .env file not found."
    exit 1
fi
source .env

INTERNAL_EXCLUDES=(Android SwiftBackup .thumbnails .trash* .mixplorer .recycle)
INTERNAL_ARGS=$(printf -- '--exclude=%s ' "${INTERNAL_EXCLUDES[@]}")'--rsync-path=/data/adb/modules/ssh/usr/bin/rsync'

WP_EXCLUDES=(.Shared .StickerThumbs .Thumbs .trash)
WP_ARGS=$(printf -- '--exclude=%s ' "${WP_EXCLUDES[@]}")'--rsync-path=/data/adb/modules/ssh/usr/bin/rsync'

KEY=(-e "ssh -i ${KEY_LOCATION}")

REMOTE_IP="$1"
REMOTE_HOST=root@"${REMOTE_IP}"

if [ -z "$REMOTE_IP" ]; then show_use; fi

if [ $# -ne 1 ]; then show_use; fi

if [ "$(command -v nmap)" ]; then
    echo 'Looking for wireless debugging port...'
    #PORT=$(nmap -sT -p30000-45000 "${REMOTE_IP}" | tail -n 3 | head -n 1 | sed -r 's/([1-9][0-9]+)(\/tcp.+)/\1/')
    PORT=$(nmap -sT -p37000-44000 "${REMOTE_IP}" | awk -F/ '/tcp open/{print $1}' )
else
    read -rp "Enter the Wireless debugging port: " PORT
fi

adb connect "${REMOTE_IP}":"${PORT}" >/dev/null 2>&1

if [ "$(adb get-state)" == "device" ]; then
    echo -e "\nConnected to ${REMOTE_IP}:${PORT}"
else
    print_error_message "\nFailed to connect to the device."
    adb disconnect
    exit 1
fi

adb shell su - -c /data/adb/modules/ssh/opensshd.init start

while true; do
    show_menu
    read -rp "Enter your choice: " choice
    echo -e "\n"
    case $choice in
    1)
        if check_ssh_connection; then
            rsync --dry-run -avhP --info=stats2 "${KEY[@]}" $INTERNAL_ARGS "${DESTINATION}"/ "${REMOTE_HOST}":"${INTERNAL}"
            confirm_action && rsync -avhP --info=stats2 "${KEY[@]}" $INTERNAL_ARGS "${DESTINATION}"/ "${REMOTE_HOST}":"${INTERNAL}"
        else
            print_error_message "Failed to establish SSH connection to ${REMOTE_HOST}"
        fi
        ;;
    2)
        if check_ssh_connection; then
            rsync --dry-run -avhP --info=stats2 "${KEY[@]}" $WP_ARGS "${DESTINATION}""${WHATSAPP}"/ "${REMOTE_HOST}":"${INTERNAL}""${WHATSAPP}"
            confirm_action && rsync -avhP --info=stats2 "${KEY[@]}" $WP_ARGS "${DESTINATION}""${WHATSAPP}"/ "${REMOTE_HOST}":"${INTERNAL}""${WHATSAPP}"
        else
            print_error_message "Failed to establish SSH connection to ${REMOTE_HOST}"
        fi
        ;;
    3)
        if check_ssh_connection; then
            rsync --dry-run -avhP --info=stats2 "${KEY[@]}" "${DESTINATION}"/SwiftBackup/ "${REMOTE_HOST}":"${INTERNAL}"/SwiftBackup
            confirm_action && rsync -avhP --info=stats2 "${KEY[@]}" "${DESTINATION}"/SwiftBackup/ "${REMOTE_HOST}":"${INTERNAL}"/SwiftBackup
        else
            print_error_message "Failed to establish SSH connection to ${REMOTE_HOST}"
        fi
        ;;
    4)
        adb shell su - -c /data/adb/modules/ssh/opensshd.init stop
        adb disconnect
        exit 0
        ;;
    *)
        print_error_message "Invalid choice. Please try again."
        ;;
    esac
done
