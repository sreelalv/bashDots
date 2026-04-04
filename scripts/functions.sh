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

bl()(        #Bluetooth control 
  if [[ "$(bluetoothctl show | grep PowerState | grep off)" ]] ; then 
	  quiet bluetoothctl power on
  fi

  local param1="$1"
  local param2="$2"
  local tmpfile="/tmp/tmp.bluetoothdevices"

  if [[ ! -f "$tmpfile" ]] ; then 
    touch "$tmpfile"
    param1="*"
  fi
	
	if [[ "${param1}" =~ [0-9]$ ]] ; then 
		param2="$param1"
		param1="con"						
	fi 
 
  declare -A bl_list 
  while read -r  key value ; do 
    bl_list["$key"]="$value"
  done < <(awk '{print $1,$3}' "$tmpfile")
  
  case $param1 in 
    interactive | i )
      bluetoothctl 
      ;;

    scan )
      ((expect -c '
      spawn bluetoothctl 
      set timeout 0
      expect "#"
      send "scan on\r"
      set timeout 5
      expect "#"
      send "exit\r"
      ' >/dev/null 2>&1)&& bl )
      
      ;; 

    connected )
      for i in ${!bl_list[@]} ; do 
        if [[ "$(bluetoothctl info ${bl_list["$i"]} | grep Connected | grep yes)" ]] ; then 
          bluetoothctl devices | grep --colour=never "${bl_list["$i"]}" 
        fi
      done
      ;; 

    con )
            
      if [[ -z "$param2" ]] ; then 
        echo "No device found" 
      else
        if [[ "$(bluetoothctl info ${bl_list[$param2]} | grep Trusted | awk '{print $2}')" == "no" ]] ;then
          quiet bluetoothctl pair "${bl_list[$param2]}"
          quiet bluetoothctl trust "${bl_list[$param2]}" 
        fi
        quiet bluetoothctl connect "${bl_list[$param2]}"
				if [[ "$(bluetoothctl devices Connected | grep ${bl_list[$param2]}))" ]] ; then 
					echo "Connection Successfull"
				fi 
      fi
      ;; 
      
    dis | disconnect) 
      if [[ -z $param2 ]] ; then 
        quiet bluetoothctl disconnect 
      else
        echo "Disconnecting ${bl_list["$param2"]}..." 
        quiet bluetoothctl disconnect ${bl_list["$param2"]}
      fi
      ;;

    rm | remove )
      if [[ -z "$param2" ]] ; then 
	      for i in ${bl_list[@]} ; do 
		      echo "Removing $i"
		      quiet bluetoothctl remove "$i"
	      done
      else
        echo "R2 ${bl_list["$param2"]}"
        quiet bluetoothctl remove "${bl_list["$param2"]}" 
      fi
      ;; 

    * )
      bluetoothctl devices | grep --colour=never Device | awk 'BEGIN{i=1}{print i" "$0 ;i++}' | tee  $tmpfile
      ;; 

  esac
)


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
      (( val j= current - val ))  
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

