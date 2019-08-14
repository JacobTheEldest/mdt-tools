#!/bin/bash

# backuprouter.sh v1.0
# By: Jacob S. Steward - Jacob.Steward@us.af.mil

# This script backs up router configs from mdt_local and mdt_remote on the ACN sim
# It should be run as the assessor user from the servicesVM


scp -r /home/jacob/mdt-scripts servicesvm:/operator/
