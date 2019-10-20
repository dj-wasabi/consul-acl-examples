#!/usr/bin/env bash

MASTER_TOKEN=$(python -c 'import sys; import json; print (json.load(sys.stdin)["acl"]["tokens"]["master"])' < config/config.json)
AGENT_TOKEN=$(python -c 'import sys; import json; print (json.load(sys.stdin)["acl"]["tokens"]["agent"])' < config/config.json)
CONSUL_HOST="consul-1"

echo "$(date +"%Y-%m-%d %H:%M:%S"): Starting the basic Consul infrastructure"
docker-compose up -d >/dev/null 2>&1

sleep 2
CONSUL_LEADER=$(curl -s localhost:8500/v1/status/leader)
while [[ "${CONSUL_LEADER}" == "\"\"" ]];do
    sleep 1
    CONSUL_LEADER=$(curl -s localhost:8500/v1/status/leader)
done

echo "$(date +"%Y-%m-%d %H:%M:%S"): Configure Agent ACL"
docker exec -e CONSUL_HTTP_TOKEN="${MASTER_TOKEN}" -it "${CONSUL_HOST}" consul acl policy create -name agent-token -rules @/tmp/hcl/agent.hcl >/dev/null
docker exec -e CONSUL_HTTP_TOKEN="${MASTER_TOKEN}" -it "${CONSUL_HOST}" consul acl token create -description "agent token" -policy-name agent-token -secret="${AGENT_TOKEN}" >/dev/null
docker exec -e CONSUL_HTTP_TOKEN="${MASTER_TOKEN}" -it "${CONSUL_HOST}" consul acl set-agent-token agent "${AGENT_TOKEN}" >/dev/null

# Configure DNS
echo "$(date +"%Y-%m-%d %H:%M:%S"): Configure DNS ACL"
# shellcheck disable=SC2086
DNS_TOKEN=$(docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl policy create -name "dns-requests" -rules @/tmp/hcl/dns.hcl | grep 'ID:' | awk '{print $2}' | tr -d '\r')
docker exec -e CONSUL_HTTP_TOKEN="${MASTER_TOKEN}" -it "${CONSUL_HOST}" consul acl token create -description "Token for DNS Requests" -policy-name dns-requests >/dev/null
docker exec -e CONSUL_HTTP_TOKEN="${MASTER_TOKEN}" -it "${CONSUL_HOST}" consul acl set-agent-token default "${DNS_TOKEN}" >/dev/null

echo "$(date +"%Y-%m-%d %H:%M:%S"): Consul Cluster configured completely"
