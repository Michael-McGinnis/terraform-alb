#!/usr/bin/env bash
#
# load_test.sh
#
# Sends HTTP requests to the ALB for one hour, pausing 0.5–2s between each.

ALB_URL="http://alb.helloalb.ip-ddns.com"   # ALB hostname
DURATION_SECONDS=3600                       # total run time (1 hour)
END_TIME=$((SECONDS + DURATION_SECONDS))

echo "Starting 1-hour load test at $(date). Hitting $ALB_URL..."

count=0
while [ $SECONDS -lt $END_TIME ]; do
  # Fire the request, discard the response body, capture only HTTP status
  HTTP_STATUS=$(curl -so /dev/null -w "%{http_code}" "$ALB_URL")
  count=$((count + 1))

  # Every 100 requests, print a progress update
  if (( count % 100 == 0 )); then
    echo "[$(date '+%H:%M:%S')] Request #$count → Status: $HTTP_STATUS"
  fi

  # Sleep a random time between 0.5 and 2 seconds
  SLEEP_SEC=$(awk -v min=0.5 -v max=2 'BEGIN { srand(); printf("%.2f\n", min + rand()*(max-min)) }')
  sleep "$SLEEP_SEC"
done

echo "Load test complete at $(date). Total requests sent: $count."