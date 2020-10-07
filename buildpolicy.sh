#!/usr/bin/env bash

auth_token=$(curl -k  --location --request POST 'https://ppdm-01.demo.local:8443/api/v2/login' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--data-raw '{
	"username": "admin",
	"password": "Password123!"
}' | jq -r '.access_token')

auth_header="Authorization: Bearer ${auth_token}"
export id=$(uuidgen)
export stages_id=$(uuidgen)
export name="kubernetest-${RANDOM}"
url="ppdm-01.demo.local"
protection_policy=$(envsubst < protection_policy.json)
echo $id
echo $name
echo $stages_id
echo $protection_policy | jq .

curl -k --request POST \
  --url https://${url}:8443/api/v2/protection-policies \
  --header "${auth_header}" \
  --header 'content-type: application/json' \
  --data '${protection_policy}'

