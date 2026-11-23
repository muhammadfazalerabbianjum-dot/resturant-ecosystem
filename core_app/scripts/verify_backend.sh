#!/bin/bash
# Check Firestore rules are deployed (read a dummy doc)
firebase firestore:get /users/testUser --project=$PROJECT_ID || exit 1

# Check Cloud Function is deployed
curl -f https://$REGION-$PROJECT_ID.cloudfunctions.net/createOrder || exit 1

echo "Backend Verification Passed."
