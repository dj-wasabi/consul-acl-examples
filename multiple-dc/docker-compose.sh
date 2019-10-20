#!/usr/bin/env bash

echo "$(date +"%Y-%m-%d %H:%M:%S"): Starting the basic Consul infrastructure"
REPLICATION_TOKEN=$(python -c 'import sys; import json; print (json.load(sys.stdin)["acl"]["tokens"]["replication"])' < config/config-dc2.json)
docker-compose up -d >/dev/null 2>&1

sleep 2
CONSUL_LEADER=$(curl -s localhost:8500/v1/status/leader)
while [[ "${CONSUL_LEADER}" == "\"\"" ]];do
    sleep 1
    CONSUL_LEADER=$(curl -s localhost:8500/v1/status/leader)
done

for DC in dc1 dc2;do
    MASTER_TOKEN=$(python -c 'import sys; import json; print (json.load(sys.stdin)["acl"]["tokens"]["master"])' < config/config-${DC}.json)
    AGENT_TOKEN=$(python -c 'import sys; import json; print (json.load(sys.stdin)["acl"]["tokens"]["agent"])' < config/config-${DC}.json)
    CONSUL_HOST="consul-${DC}"

    echo "$(date +"%Y-%m-%d %H:%M:%S"): Configure Agent ACL ($DC)"
    docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl policy create -name agent-token -rules @/tmp/hcl/agent.hcl >/dev/null
    docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl token create -description "agent token" -policy-name agent-token -secret=${AGENT_TOKEN} >/dev/null
    docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl set-agent-token agent "${AGENT_TOKEN}" >/dev/null

    if [[ "${DC}" == "dc1" ]]; then
        # Configure DNS
        echo "$(date +"%Y-%m-%d %H:%M:%S"): Configure DNS ACL ($DC)"
        DNS_TOKEN=$(docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl policy create -name "dns-requests" -rules @/tmp/hcl/dns.hcl | grep 'ID:' | awk '{print $2}' | tr -d '\r')
        docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl token create -description "Token for DNS Requests" -policy-name dns-requests >/dev/null
        docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl set-agent-token default "${DNS_TOKEN}" >/dev/null
        docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl policy create -name replication -rules @/tmp/hcl/replication.hcl >/dev/null
        docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl token create -description "replication token" -policy-name replication -secret=${REPLICATION_TOKEN} >/dev/null
    fi
    docker exec -e CONSUL_HTTP_TOKEN=${MASTER_TOKEN} -it ${CONSUL_HOST} consul acl set-agent-token replication ${REPLICATION_TOKEN} >/dev/null
done

COUNTER=0
until docker logs consul-dc1 2>&1 | grep -- 'EventMemberUpdate: consul-dc2.dc2' >/dev/null || [ $COUNTER -eq 60 ]; do
    sleep 1
    COUNTER=$(expr $COUNTER + 1)
done

echo "$(date +"%Y-%m-%d %H:%M:%S"): Consul Cluster configured completely"
