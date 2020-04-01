#!/bin/sh
sleep 10
cd /opt/fastd-commitcheck
./check-dublicates.sh | ruby irc.rb 
#> /dev/null 2>&1
