#!/bin/bash

# backuprouter.sh v1.0
# By: Jacob S. Steward - Jacob.Steward@us.af.mil

# This script backs up router configs from mdt_local and mdt_remote on the ACN sim
# It should be run as the assessor user from the servicesVM


mkdir "/operator/backup/$(date +%Y%m%d)"
scp mdt_local:running-config "/operator/backup/$(date +%Y%m%d)/MDT_Local-running_config-$(date +%Y%m%d_%H%M)"
scp mdt_remote:running-config "/operator/backup/$(date +%Y%m%d)/MDT_Remote-running_config-$(date +%Y%m%d_%H%M)"
