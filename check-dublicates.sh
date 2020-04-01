#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
export HOME=/home/fftr-webhooks
cd /var/opt/fftr-webhooks/fftr-peers
if ! git pull > /dev/null 2>&1; then
	exit
fi
TMPFILE=`mktemp /tmp/fftr-peers-dubchecker-XXXXXX`
#grep --no-filename "key" * | grep -v '#' | egrep -o "(seg_[0-9]+/)?[-_0-9a-f]{60,80}" | sort | uniq -d > $TMPFILE
grep --no-filename "key" * seg_*/* | egrep -o "[0-9a-f]{60,80}" | sort | uniq -d > $TMPFILE
  ### IRC message formatting.  For reference:
  ### \002 bold   \003 color   \017 reset  \026 italic/reverse  \037 underline
  ### 0 white           1 black         2 dark blue         3 dark green
  ### 4 dark red        5 brownish      6 dark purple       7 orange
  ### 8 yellow          9 light green   10 dark teal        11 light teal
  ### 12 light blue     13 light purple 14 dark gray        15 light gray

#  def fmt_url(s)
#    "\00302\037#{s}\017"
#  end
if [ -s "$TMPFILE" ]; then
  echo '/COLOR-RED-ESCAPE/found duplicate keys:/COLOR-RESET-ESCAPE/'
  cat "$TMPFILE" | head -n 3 | while read i; do
    echo -n "$i ("
#    grep -F "$i" -l -r . | sed 's-./--' | egrep -o "[-._0-9a-zA-Z]{0,80}" | while read node; do
     grep -F "$i" -l -r . | egrep -o "(seg_[0-9]+/)?[-_0-9a-zA-Z]{0,80}" | while read node; do
     echo -n "$node, ";
    done | head -c -2
    echo ")"
  done

#  echo -n "Removing keys: "
#  cat "$TMPFILE" | while read i; do
#    MINTIME=9999999999
#    MINFILE=""
#    grep -F "$i" -l -r . | sed 's-./--'| egrep -o "[-._0-9a-zA-Z]{0,80}" | while read node; do
#      TIME=`git log -n 1 --format=format:%ct "$node"`
#      if [ "$TIME" -lt "$MINTIME" ]; then
#        MINTIME="$TIME"
#        MINFILE="$node"
#      fi
#      echo "$MINFILE" > "$TMPFILE-2"
#    done
#    MINFILE="$(cat "$TMPFILE-2")"
#    if [ -f "$MINFILE" ]; then
#      echo -n "$MINFILE, "
#      git rm "$MINFILE" > /dev/null 2>&1
#    fi
#  done | head -c -2
#  echo
##  git commit -m "fftr-commitcheck: removed duplicate keys" >/dev/null 2>&1
##  git push writable >/dev/null 2>&1

else
  echo '/COLOR-GREEN-ESCAPE/found no duplicate keys/COLOR-RESET-ESCAPE/'
fi
#/COLOR-RED-ESCAPE/ \00304\037
#/COLOR-GREEN-ESCAPE/ \00303\037
#/COLOR-RESET-ESCAPE/ \017
rm -f $TMPFILE "$TMPFILE-2"
