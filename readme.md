# Consul ACL Examples

This repository contains 2 examples of Consul Cluster configurations that works with the recent implementation of ACL in Consul.

The example resides in the following directories:

* single-dc
* multi-dc

## single-dc

This example starts 3 Docker Consul containers named `consul-1`, `consul-2` and `consul-3`.

The following ACL's are created:

* "agent": `7a59f860-7e6a-0037-52d6-270ee84e4bed`
* "master": `9a6c723f-2533-2679-4515-654cdb7f96c9`

Within the `hcl` directory, 2 hcl files can be found that contains the configuration for the roles.

## multi-dc

This example starts 2 Docker Consul containers named `consul-dc1` and `consul-dc2`. 