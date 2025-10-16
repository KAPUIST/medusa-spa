#!/bin/bash

# Wait for Medusa server to be ready
# Default timeout: 60 seconds
# Default port: 9000

TIMEOUT=${1:-60}
PORT=${2:-9000}
COUNTER=0

echo "Waiting for Medusa server on port $PORT to respond..."

until curl -f http://localhost:$PORT/health >/dev/null 2>&1; do
  COUNTER=$((COUNTER + 1))

  if [ $COUNTER -ge $TIMEOUT ]; then
    echo "Timeout waiting for server on port $PORT"
    exit 1
  fi

  echo "Waiting... ($COUNTER/$TIMEOUT)"
  sleep 1
done

echo "Server is ready!"
