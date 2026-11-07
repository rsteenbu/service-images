#!/bin/sh
# Update the home.steenburg.net A record in Route53 to the current public IP
# of this host's ISP connection. Runs hourly via cron on n100d as rsteenbu.
# See ./README.md for context.

MY_IP=$(curl -s http://ifconfig.net)

ZONE="Z3LL68C7O2MBKT"
NAME_TAG="home.steenburg.net"

aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'$NAME_TAG'","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'$MY_IP'"}]}}]}' 2>&1 | logger
