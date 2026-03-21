#!/bin/bash


background(){
  (( "$@" >/dev/null 2>&1 && [[ $? -eq 0 ]] && (notify-send "Task Completed" "$*") || (notify-send "Task Failed" "$*") )&)
}

run(){
  (("$@" > /dev/null  2>&1 )&) 
}

quiet(){
  ("$@" >/dev/null 2>&1)
}

bl(){        #Bluetooth control 
  if [[ -z $1 ]] ; then 
    bluetoothctl devices |grep --colour=never Device | awk 'BEGIN{i=1}{print i" "$0 ;i++}'
  else 
    if [[ "$1" = "dis" ||  "$1" = "disconnect" ]] ; then
      quiet bluetoothctl disconnect
    elif [ "$1" = "scan" ] ; then
      ((expect -c '
      spawn bluetoothctl 
      set timeout 0
      expect "#"
      send "power on\r"
      set timeout 5
      expect "#"
      send "scan on\r"
      set timeout 5
      expect "#"
      send "exit\r"
      ' >/dev/null 2>&1)&& bl)
    elif [[ "$1" = "i" ||  "$1" = "interactive" ]] ; then 
      bluetoothctl 
    else
      if [[ "$1" =~ "[0-9]" ]]; then
        device="$(bluetoothctl devices | awk -v value="$1" 'NR==value{print $2}')"
        echo "$device"
      else
        device="$(bluetoothctl devices | grep -i "$1" | awk '{print $2}')" 
        if [[ -z "$device" ]] ; then 
          echo "No device found" 
          exit 
        fi
      fi

      if [[ "$(bluetoothctl info $device | grep Trusted | awk '{print $2}')" == "no" ]] ;then
        quiet bluetoothctl pair "$device"
        quiet bluetoothctl trust "$device" 
      fi
      quiet bluetoothctl connect "$device"
    fi 
  fi 
}

bri(){        # Brightness control 
  current="$(brightnessctl i | awk 'NR==2{print $3/120000*100}')"
  val="$1"

  if [[ -z $val ]] ; then 
    echo "Brightness set $current%" 
  else 
    if [[ "$val" =~ ^[0-9]+$ ]] ;then 
    : 
    elif [[ "$val" =~ ^[+][0-9]+$ ]]; then
      (( val = current + val )) 
    elif [[ "$val" =~ ^[-][0-9]+$ ]]; then 
      val="$(echo $val | tr -d '-')" 
      (( val = current - val ))  
    fi 
    if [[ $val -lt 5 ]]; then 
      ((val = 5))
    fi
    brightnessctl set "$val%" > /dev/null && echo "$(bri)"
  fi
}


aria(){ 
	local input="$1"
	local _aria_="aria2c -x 16 -s 16 -j 8"
	local dir="-d $HOME/Downloads/aria/"
	local con="--continue=true" 
	local overwrite="--allow-overwrite"
	local torrent="--enable-dht=true --bt-enable-lpd=true --bt-max-peers=50 --seed-time=0"

	if [[ $input =~ torrent$ || $input =~ ^magnet ]] ; then
		_aria_="${_aria_} ${torrent}"
	fi
	_aria_="${_aria_} ${dir}" 

	if [[ "$2" = "-o" || "$2" = "overwrite" ]] ; then 
		_aria_="${_aria_} ${overwrite}"
	
	elif [[ "$2" = "-c" || "$2" = "--continue" ]] ; then 
		_aria_="${_aria_} ${con}"
	fi
	echo "$_aria_ $input"
	$_aria_ "$input" && (( $? == 0 )) && exit 
}

