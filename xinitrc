#!/bin/sh

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

export PATH=$PATH:/usr/bin

#adding fonts folder.
test -d /usr/share/fonts/local && xset +fp /usr/share/fonts/local
xset fp rehash
xset -b # disable bell

# merge in defaults and keymaps

if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi


#while true; do xsetroot -name "$(date +"%F %R")"; sleep 30s; done &
~/config_files/bin_configs/dwm_status & 

localectl set-x11-keymap latam pc105 &
#Display resolution.
xrandr --output eDP-1  --mode 1920x1080 &

insyncprocess=$(ps aux | grep insync | wc -l )
if [ "1" -le $insyncprocess ]; then
	insync start &
fi
	
#background image
feh --bg-scale ~/config_files/wallpapers/arch-linux-wallpaper.png &
#swap mouse buttons.
# 14 or first number is the mouse id get by xinput list
xinput set-button-map 14 3 2 1

#Compositor
#picom -f &
picom &
redshift &
#redshift -l -33.4:70.6 -t 5700:3600 -g 0.8 -m randr -v
exec dwm
#twm &
#xclock -geometry 50x50-1+1 &
#xterm -geometry 80x50+494+51 &
#xterm -geometry 80x20+494-0 &
#exec xterm -geometry 80x66+0+0 -name login
