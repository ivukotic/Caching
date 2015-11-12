PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
metricpath="test.stats.uct3-xrdcache."
date=`date +%s`
function send_to_graphite {
   echo $metricpath$1 $2 $date
}

# 2. cache disk occupancy
#size=`df /dev/sdc | awk '{print $3}' | grep -v Used`
size=`du -s /xrootd | awk {'print $1'}`
send_to_graphite cachesize $size

# 3. age of the oldest file in cache (in seconds)
fileage=`stat -c %Y $(find /xrootd -type f -printf '%T@ %p\n' | grep user | grep -v cinfo | sort | head -1 | awk '{print $2}')`
send_to_graphite oldestfile $((date-fileage))

# 4. average percentage of the file cached
# /usr/bin/xrdpfc_print

cached=0
total=0

#function increment {
#  if [ "$1" -ne "0" ];
#  then
#    cached=$(echo "scale=8; $cached + ($1 / $2)" | bc)
#    total=$(($total+1))
#  fi
#}
function increment {
  if [ "$1" -ne "0" ];
  then
    cached=$(($cached+$1))
    total=$(($total+$2))
  fi
}

files=`find /xrootd -iname "*.cinfo"`
for file in $files;
do
#   accesses=`/usr/bin/xrdpfc_print $file | tail -2 | awk '{print $2}'`
#   echo $accesses
  increment $(/usr/bin/xrdpfc_print $file | grep version | awk '{print $9,$7}')
done
pcached=$(echo "scale=8; $cached / $total" | bc)
send_to_graphite percentcached $(echo "scale=8; 100 * $cached / $total" | bc)

export TZ=GMT
currMonth=$(date +%Y-%m)
ts=$(date +%Y-%m-%dT%H:%M:%S)
curl -XPOST http://cl-analytics.mwt2.org:9200/caching-$currMonth/fromcache/ -d "{\"timestamp\": \"$ts\", \"hostname\":\"$(hostname)\",\"size\" : $(( size * 1024 )), \"oldestfile\" : $((date-fileage)),\"percentcached\" : $pcached}"
