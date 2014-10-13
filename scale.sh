#!/usr/bin/env bash
# Get haproxy queue and call add or del server playbook.
# Usage: ./<scriptname> <webfarm> <BACKEND>

# !Todo: No user input validation
maxqueu=$1 # max queue size
maxserv=4  # max servers
currque=0  # current servers
counter=0  # start with empty counter

webfarm="webfarm"  # Name of haproxy webserver group
backend="BACKEND"  # Name of haproxy webserver group statisctics row

echo "- Scaling starts when more then $1 requests are waiting in the queue"
echo "- Scaling to the maximum of 4 servers"
echo "- When there are no more requests waiting, scale down to minimun of one server"
echo ""

while true
do
    queue=$(curl -u admin:hadmin "http://213.187.241.159:443/stats/;csv" 2>/dev/null | grep "^$webfarm,$backend" |cut -d, -f 3)
    if [ -z "$queue" ]; then
            echo "ERROR: Please HAproxy fix URL"
            exit 1
    elif [ "$queue" -gt "$maxqueu" ]; then
        if [ "$currque" -ge "$maxserv" ]; then
                echo "Max servers exceeded, please raise the limit"
        else
                currque=$[currque + 1]
                echo "Queu waiting limit exceeded, spawning extra server to handle extra requests"
                echo "Spawning web-extra-"$currque
                /usr/local/bin/ansible-playbook -i inventory add_server.yml --extra-vars "servername=web-extra-$currque" > /dev/null 2>&1
                sleep 15 # new server warmup
                counter=$[counter + 10] # 30 points for the new server
        fi
    elif [ "$counter" -gt 0 ]; then
                counter=$[counter - 1]
    elif [ "$counter" == 0 ]; then
        if [ "$currque" -gt 0 ]; then
            server="web-extra-$currque"
            echo "Looks good, scaling down and removing: "$server
            sed -e /"$server"/d -i inventory # Nasty hack because ansible cannot change the inventory file, please use dynamic inventory.
            currque=$[currque - 1]
            /usr/local/bin/ansible-playbook -i inventory del_server.yml --extra-vars "servername="$server > /dev/null 2>& 1
        fi
    fi
    echo "Everything is fine, currently waiting requests: $queue"
    if [ ! "$counter" == 0 ]; then
        echo "Countdown to scale (down): " $counter
    fi
    sleep 1
done
