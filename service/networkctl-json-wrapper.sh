#!/bin/bash
# Wrapper script to call DBus service and format output as JSON

output=$(qdbus6 org.kde.plasma.networkctl /NetworkCtl org.kde.plasma.networkctl.ListInterfaces 2>&1)

if [ $? -ne 0 ]; then
    echo '[]'
    exit 0
fi

# Parse the output and convert to JSON
echo "$output" | awk '
BEGIN {
    print "["
    count = 0
}
/administrativeState:/ {
    if (count > 0) print ","
    admin = $2
    getline
    oper = $2
    printf "  {\"administrativeState\": \"%s\", \"operationalState\": \"%s\", \"name\": \"eth%d\", \"type\": \"ethernet\"}", admin, oper, count
    count++
}
END {
    print ""
    print "]"
}'
