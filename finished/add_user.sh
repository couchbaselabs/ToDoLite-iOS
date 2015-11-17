#!/bin/bash
curl -vX POST -H 'Content-Type: application/json' \
    -d '{"name": "oliver", "password": "letmein"}' \
    http://localhost:4985/todos/_user/
