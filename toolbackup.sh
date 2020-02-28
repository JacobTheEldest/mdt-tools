#!/bin/bash

# toolbackup.sh v1.0
# By: Jacob S. Steward - Jacob.Steward@us.af.mil

# This script backs up mdt-tools to the servicesVM

scp -r /home/jacob/mdt-tools servicesvm:/operator/
