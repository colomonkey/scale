#!/usr/bin/env bash
# Get haproxy queue and call add or del server playbook.
# Usage: ./<scriptname> <webfarm> <BACKEND>

maxqueu=10 # max queue size
maxserv=3  # max servers
currque=0  # current servers
counter=0  # start with empty counter

while true
do
    queue=$(curl -u admin:hadmin "http://0.0.0.0:8808/stats/;csv" 2>/dev/null | grep "^$1,$2" |cut -d, -f 3)
    if [ -z "$queue" ]; then
            echo "ERROR: Please HAproxy fix URL"
            exit 1
    elif [ "$queue" -gt "$maxqueu" ]; then
        if [ "$currque" -ge "$maxserv" ]; then
                echo "Max servers exceeded, please raise the limit"
        else
                currque=$[currque + 1]
                echo "Queu limit exceeded, spawning extra server"
                echo "Spawning web-extra-"$currque
                /usr/local/bin/ansible-playbook -i inventory add_server.yml --extra-vars "servername=web-extra-$currque"
                sleep 60 # new server warmup
                counter=$[counter + 30] # 30 points for the new server
        fi
    elif [ "$counter" -gt 0 ]; then
                counter=$[counter - 1]
    elif [ "$counter" == 0 ]; then
        if [ "$currque" -gt 0 ]; then
            server="web-extra-$currque"
            echo "Scaling down, removing: "$server
            sed -e /"$server"/d -i inventory # Nasty hack because ansible cannot change the inventory file
            currque=$[currque - 1]
            /usr/local/bin/ansible-playbook -i inventory del_server.yml --extra-vars "servername="$server
        fi
    fi
    echo "Everything is fine, queuesize: $queue"
    echo "Counter: " $counter
    sleep 1
done
