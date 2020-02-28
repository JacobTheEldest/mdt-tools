#!/bin/python3

'''
acnidconfgen.py v1.5
Written by Jacob S. Steward - jacob.steward@us.af.mil
Created: 20191022 (Supercedes geoipconfgen.py)
Last Updated: 20191119


EXPECTATIONS:
- Intended to be run with python3
- Must be run with root permissions
- sites.csv	
	- Expects an input file named "sites.csv" containing info in the format "Site_ID_number, Site Name" on each line.
	- One per line, with no blank lines or lines containing anything else. Ex: "1,123 Example Squadron"
- types.csv
	- Expects an input file named "types.csv" containing info in the format "Network/Device_Type_IP_ID, Network Name" on each line.
	- One per line, with no blank lines or lines containing anything else. Ex1: "102,Primary CTP" Ex2: "254,Network Management"
- devices.csv
	- Expects an input file named "devices.csv" containing info in the format "IP_Address,Device Name" on each line.
	- One per line, with no blank lines or lines containing anything else. Ex1: "10.1.2.1,GCS1"


OUTPUT:
Generates a logstash config file to appropriately tag each IP in private IP address ranges with the following:
	- Unit/Location Names for Sites
	- Network/Device Types
	- Specific Device


USAGE:
- Ensure mdt-tools directory is in the PATH
	- ex: dockervm:/etc/profile.d/extrapaths.sh
		if [ -d /home/assessor/mdt-tools ]; then
			pathprepend /home/assessor/mdt-tools
		fi
- Ensure acnidconfgen.py is executable
- Run command 'acnidconfgen.py' as root


CHANGELOG:
v0.8 - Generate conf file to add Site info
v0.9 - Added network type info
v1.0 - Added specific device name info
v1.1 - Script now automatically places the output file and keeps backups of the last 10
v1.2 - Added input validation and error checking
v1.3 - Added some print commands to explain what's going on.
v1.4 - Add command line options
v1.5 - Generalized backup feature as a function


TODO:

'''


################################################################################
######## Initial Setup                                                  ######## 
################################################################################

######## Imports

import datetime # Necessary to insert file creation
import os # Necessary for filesystem functions
import shutil # Necessary for file moves between filesystems
import argparse # Library for command line flags


######## Function Declarations

# Function to unpack two-field CSVs into a key-value pair dictionary
def csv_dict(filepath):
    with open(filepath) as file:
        contents = file.readlines()
    out_dict = {}
    for line in contents:
        if ',' not in line: # Skip lines that do not have a comma
            print("The following line in file '{}' is not properly formatted".format(filename))
            print(line, '\n')
            continue
        ip, value = line.split(",")
        out_dict[ip.strip()] = value.strip()
    return out_dict


######## Function to create a specified number of backups of a file
def backup(filepath, backups):
    for i in range(backups-1,0,-1):
        if os.path.exists(os.path.join(filepath+str(i))):
            os.rename(os.path.join(filepath+str(i)), os.path.join(filepath+str(i+1)))
    if os.path.exists(os.path.join(filepath)):
        os.rename(os.path.join(filepath), os.path.join(filepath+'1'))
    return


######## Support CLI arguments
parser = argparse.ArgumentParser() # Create argument parser

# Use 'dest' option if you want a variable different than the long option string
parser.add_argument('-b', '--backups', type=int, default=10, help="number of old config files to keep (default: %(default)s)")
parser.add_argument('-i', '--inputdirectory', dest='input_dir', default=os.getcwd(), help="input directory (default: current directory")
parser.add_argument('-o', '--outputdir', dest='output_dir', default="/operator/dip/syoo-logstash/configs", help="configuration output directory (default: %(default)s)")
parser.add_argument('-f', '--filename', default="8002_postprocess_acn_ip_identification.conf", help="config filename (default: %(default)s)")
parser.add_argument('-u', '--uid', type=int, default=1000, help="owning UID of config file (default: %(default)s)")
parser.add_argument('-g', '--gid', type=int, default=1000, help="owning GID of config file (default: %(default)s)")

args = parser.parse_args() # Parse the arguments


######## Declare Const Variables
SITES_FILE = 'sites.csv'
TYPES_FILE = 'types.csv'
DEVICES_FILE = 'devices.csv'


######## Initialize Variables

# Default to quit until a CSV is loaded
csv_exists = False

# Build filepaths
sites_path = os.path.join(args.input_dir, SITES_FILE)
types_path = os.path.join(args.input_dir, TYPES_FILE)
devices_path = os.path.join(args.input_dir, DEVICES_FILE)
config_path = os.path.join(args.input_dir, args.filename)
config_dest_path = os.path.join(args.output_dir, args.filename)


######## Ensure this script was run as root
if not os.geteuid() == 0:
    raise PermissionError("Error! This script must be run as root.")


######## Read contents of input files
if os.path.exists(sites_path):
    csv_exists = True
    sites = csv_dict(sites_path)
    print("Loaded {}".format(SITES_FILE))
if os.path.exists(types_path):
    csv_exists = True
    types = csv_dict(types_path)
    print("Loaded {}".format(TYPES_FILE))
if os.path.exists(devices_path):
    ips = csv_dict(devices_path)
    devices = {}
    for key in ips.keys():
        network, site_id, type_id, device_id = key.split('.')
        if site_id not in devices.keys():
            devices[site_id] = {}
        if type_id not in devices[site_id].keys():
            devices[site_id][type_id] = {}
        devices[site_id][type_id][device_id] = ips[key]
        # Handle the case of devices with unknown sites
        if sites and (site_id not in sites):
            print("Device '{}' has an unknown site ID. Using 'Unknown.'".format(ips[key]))
            sites[site_id] = 'Unknown'
    print("Loaded {}".format(DEVICES_FILE))

if not csv_exists:
    raise IOError("Error! Missing input csv files.")

######## Validate dictionary fields as proper input
if sites:
    for key in sites.keys():
        try:
            if int(key) < 0:
                raise ValueError("Error! Site ID value '{}' out of range.".format(key))
            elif int(key) > 255:
                raise ValueError("Error! Site ID value '{}' out of range.".format(key))
        except ValueError:
            print("Error! Site ID value '{}' is not a proper integer.".format(key))

if types:
    for key in types.keys():
        try:
            if int(key) < 0:
                raise ValueError("Error! Type ID value '{}' out of range.".format(key))
            elif int(key) > 255:
                raise ValueError("Error! Type ID value '{}' out of range.".format(key))
        except ValueError:
            print("Error! Type ID value '{}' is not a proper integer.".format(key))

if ips:
    for ip in ips.keys():
        octets = ip.split('.')
        for octet in octets:
            try:
                if int(octet) < 0:
                    raise ValueError("Error! Octet value '{}' out of range in IP '{}'.".format(octet, ip))
                elif int(octet) > 255:
                    raise ValueError("Error! Octet value '{}' out of range in IP '{}'.".format(octet, ip))
            except ValueError:
                print("Error! Octet value '{}' is not a proper integer.".format(octet))


################################################################################
######## Write the config file                                          ######## 
################################################################################

######## Open output file for writing
with open(config_path, 'w') as conf_file:
    print("\nOpening config file for writing: {}".format(args.filename))

######## Write the header of the config file 
    conf_file.write('''# Date: 20191022
# Author: Jacob S. Steward - jacob.steward@us.af.mil
#
# {} update by acnidconfgen.py


'''.format(datetime.datetime.now().strftime('%Y%m%d')))


######## Open common configuration conditional
    conf_file.write('''filter {
  if [source_ip] {
''')


######## Loop through input file lines and create else-if blocks  
######## for each piece of data to be included.                   

# Conditionals for Sites - 10.site.x.x
    for i, site_id in enumerate(sites):
        if not i:
            conf_file.write('''
    if [source_ip] =~ "^10\.{}\." {{
      mutate {{
        add_field => {{ "original_country_code" => "{}" }}
      }}
'''.format(site_id, sites[site_id]))
        else:
            conf_file.write('''    }} else if [source_ip] =~ "^10\.{}\." {{
      mutate {{
        add_field => {{ "original_country_code" => "{}" }}
      }}
'''.format(site_id, sites[site_id]))

# Conditionals for Site-Specific Devices - 10.site.type.device
        if site_id in devices:
            for i, type_id in enumerate(devices[site_id]):
                if not i:
                    for i, device_id in enumerate(devices[site_id][type_id]):
                        if not i:
                            conf_file.write('''
      if [source_ip] =~ "^10\.{}\.{}\.{}" {{
        mutate {{
          add_field => {{ "source_device" => "{}" }}
        }}
'''.format(site_id, type_id, device_id, devices[site_id][type_id][device_id]))
                        else:
                            conf_file.write('''      }} else if [source_ip] =~ "^10\.{}\.{}\.{}" {{
        mutate {{
          add_field => {{ "source_device" => "{}" }}
        }}
'''.format(site_id, type_id, device_id, devices[site_id][type_id][device_id]))
                else:
                    for device_id in devices[site_id][type_id]:
                        conf_file.write('''      }} else if [source_ip] =~ "^10\.{}\.{}\.{}" {{
        mutate {{
          add_field => {{ "source_device" => "{}" }}
        }}
'''.format(site_id, type_id, device_id, devices[site_id][type_id][device_id]))
            conf_file.write('      }\n\n') # Close last device conditional

# Conditionals for Device Types - 10.x.type.x
    for i, type_id in enumerate(types):
        if not i:
            conf_file.write('''    }}

    if [source_ip] =~ "^10\.\d{{1,3}}\.{}\." {{
      mutate {{
        add_field => {{ "source_type" => "{}" }}
      }}
'''.format(type_id, types[type_id]))
        else:
            conf_file.write('''    }} else if [source_ip] =~ "^10\.\d{{1,3}}\.{}\." {{
      mutate {{
        add_field => {{ "source_type" => "{}" }}
      }}
'''.format(type_id, types[type_id]))


######## Close the Source IP section and open the Destination IP section
    conf_file.write('''    }

  }


  if [destination_ip] {
''')


######## Loop through input file lines and create else-if blocks  
######## for each SiteID/Unit pair Destination IP.                

# Conditionals for Sites - 10.site.x.x
    for i, site_id in enumerate(sites):
        if not i:
            conf_file.write('''
    if [destination_ip] =~ "^10\.{}\." {{
      mutate {{
        add_field => {{ "destination_geo.country_name" => "{}" }}
      }}
'''.format(site_id, sites[site_id]))
        else:
            conf_file.write('''    }} else if [destination_ip] =~ "^10\.{}\." {{
      mutate {{
        add_field => {{ "destination_geo.country_name" => "{}" }}
      }}
'''.format(site_id, sites[site_id]))

# Conditionals for Site-Specific Devices - 10.site.type.device
        if site_id in devices:
            for i, type_id in enumerate(devices[site_id]):
                if not i:
                    for i, device_id in enumerate(devices[site_id][type_id]):
                        if not i:
                            conf_file.write('''
      if [destination_ip] =~ "^10\.{}\.{}\.{}" {{
        mutate {{
          add_field => {{ "destination_device" => "{}" }}
        }}
'''.format(site_id, type_id, device_id, devices[site_id][type_id][device_id]))
                        else:
                            conf_file.write('''      }} else if [destination_ip] =~ "^10\.{}\.{}\.{}" {{
        mutate {{
          add_field => {{ "destination_device" => "{}" }}
        }}
'''.format(site_id, type_id, device_id, devices[site_id][type_id][device_id]))
                else:
                    for device_id in devices[site_id][type_id]:
                        conf_file.write('''      }} else if [destination_ip] =~ "^10\.{}\.{}\.{}" {{
        mutate {{
          add_field => {{ "destination_device" => "{}" }}
        }}
'''.format(site_id, type_id, device_id, devices[site_id][type_id][device_id]))
            conf_file.write('      }\n') # Close last device conditional

# Conditionals for Device Types - 10.x.type.x
    for i, type_id in enumerate(types):
        if not i:
            conf_file.write('''    }}

    if [destination_ip] =~ "^10\.\d{{1,3}}\.{}\." {{
      mutate {{
        add_field => {{ "destination_type" => "{}" }}
      }}
'''.format(type_id, types[type_id]))
        else:
            conf_file.write('''    }} else if [destination_ip] =~ "^10\.\d{{1,3}}\.{}\." {{
      mutate {{
        add_field => {{ "destination_type" => "{}" }}
      }}
'''.format(type_id, types[type_id]))


######## Write the end of the config file.                        
    conf_file.write('''    }

  }
}
''')
    print("Wrote config to {} for review\n".format(config_path))


################################################################################
######## Move the config file to appropriate location and set           ######## 
######## permissions.                                                   ######## 
################################################################################

######## Backup previous x number of config files
print("Creating up to 10 backups of {}".format(config_dest_path))
backup(config_dest_path, args.backups)


######## Move config file to args.output_dir and set proper ownership
shutil.copyfile(config_path, config_dest_path)
print("\nCopying new config file to {}.".format(config_dest_path))
os.chown(config_dest_path, args.uid, args.gid)
print("\nSetting ownership of config file '{}' to UID: {} and GID: {}".format(config_dest_path, args.uid, args.gid))
