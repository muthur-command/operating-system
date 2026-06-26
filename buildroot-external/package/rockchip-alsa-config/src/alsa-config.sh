#!/bin/sh
# ALSA configuration script for Rockchip boards

case "$1" in
    start)
        # Restore ALSA mixer settings
        if [ -f /etc/alsa/state.conf ]; then
            alsactl restore
        fi
        ;;
    stop)
        # Save ALSA mixer settings
        alsactl store
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
