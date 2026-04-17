#!/bin/bash

# Script based on former work of Gerhard Stahl for IT Service Stahl GmbH from 5/2018
# and adapted by THB-RZ member Gerhard Stahl in 04/2026 for Technische Hochschule Bingen
#
# This scripts build a new keystore with pkcs12 server cert for the talend interface
# The scripts expects the key for the server certificate as file server.key
# The certificate (full chain with Root CA, intermediate and server cert) is expected
# as file server.crt
# Booth files must be in the same directory as the script and must be in pem format.
#
# Some explanations of variables used below
# THB_SSL_KEY_PASSWORD is the password for the pkcs12 key
# THB_SSL_PASSWORD is the password for the keystore
#
# The passwords must be defined in the ENV_FILE. The form is:
# THB_SSL_PASSWORD='mysecret4keystore'
# THB_SSL_KEY_PASSWORD='mysecret4sslkey'
# The name of the config file defined in ENV_FILE is talend.env
#


#
# Tools
#

KEYTOOL=/usr/bin/keytool


#
# Vars
#

# Just for debug output for output the passwords read from the ENV_FILE
# 0 = no debug output
# 1 = print the values on console
DEBUG=0

# .env file for talend
ENV_FILE=talend.env

# New keystore.jks to be created
KEYSTORE_NEW=keystore.jks-new

# ANSI colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"  # No Color


#
# Functions
#

# Error check for cmds
check_status() {
    local status=$1
    local success_msg=$2
    local error_msg=$3

    if [ "$status" -ne 0 ]; then
        echo -e "${RED}${error_msg} (exit code $status)${NC}" >&2
        exit "$status"
    else
        echo -e "${GREEN}${success_msg}${NC}"
    fi
}


#
# Main program starts here
#

echo "*** Build new keystore file (${KEYSTORE_NEW}) for talend. ***"
echo "Check for required tools..."

# Check for required tool openssl
# We are lazy and avoid using a fixed path as this is different
# on Mac OS X and Linux
if command openssl -h &>/dev/null; then
    echo -e "${GREEN}openssl found. Proceeding...${NC}"
else
    echo -e "${RED}Error: openssl not found or not in path.${NC}"
    exit 1
fi

# Check for required tool keystore
if [ -x "${KEYTOOL}" ]; then
    echo -e "${GREEN}keytool found at ${KEYTOOL}. Proceeding...${NC}"
else
    echo -e "${RED}Error: keytool not found at ${KEYTOOL}.${NC}"
    echo "Install it with something like this:"
    echo "  sudo apt install openjdk-21-jre-headless"
    echo "Hint: The real version might vary depending on your OS"
    exit 1
fi

# Load the variables
# 1. Check if the file exists
if [ -f "${ENV_FILE}" ]; then
    # 2. Start automatically exporting all variables
    set -a
    # 3. Load the file
    source ${ENV_FILE}
    # 4. Stop automatically exporting
    set +a
else
    echo -e "${RED}Error: ${ENV_FILE} file not found.${NC}"
    exit 1
fi

# Delete target keystore file if it's there and user agreed
if [ -f "${KEYSTORE_NEW}" ]; then
    read -p "Target Keystore file '${KEYSTORE_NEW}' exists. Delete it? (y/N): " confirm
    case "$confirm" in
        [yY])
            rm -f "${KEYSTORE_NEW}"
            echo "Deleted file ${KEYSTORE_NEW}."
            ;;
        *)
            echo "Aborted."
            exit 1
            ;;
    esac
fi

# If debug output if required
if [ $DEBUG -eq 1 ];then
    echo "The value of THB_SSL_KEY_PASSWORD for the ssl key is: $THB_SSL_KEY_PASSWORD"
    echo "The value of THB_SSL_PASSWORD for the keystore is: $THB_SSL_PASSWORD"
fi

# creates a pkcs12 cert file from keyfile and cert in pem format
openssl pkcs12 -export -out zitinterfaceruntime.p12 -inkey ./server.key -in ./server.crt -passout pass:${THB_SSL_KEY_PASSWORD}

check_status $? \
    "New pkcs12 file zitinterfaceruntime.p12 successfully created." \
    "Error: Failed to create new pkcs12 file zitinterfaceruntime.p12."

# Creates a Java keystore for Talend
${KEYTOOL} -importkeystore \
  -srckeystore zitinterfaceruntime.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass "${THB_SSL_KEY_PASSWORD}" \
  -destkeystore ${KEYSTORE_NEW} \
  -deststoretype JKS \
  -deststorepass "${THB_SSL_PASSWORD}" \
  -destkeypass "${THB_SSL_KEY_PASSWORD}" \
  -noprompt 2>/dev/null

check_status $? \
    "New Keystore ${KEYSTORE_NEW} successfully created." \
    "Error: keytool command to build a new keystore (${KEYSTORE_NEW} failed."

# List contents of keystore to verify it
echo -e "${GREEN}Verifying new entry in Keystore ${KEYSTORE_NEW}...${NC}"
${KEYTOOL} -list -v -keystore ${KEYSTORE_NEW} -storepass "${THB_SSL_PASSWORD}" 2>/dev/null

check_status $? \
    "New Keystore ${KEYSTORE_NEW} successfully created and it's readable." \
    "Error: Failed to build new keystore (${KEYSTORE_NEW})."

# Give user hint for viewing the keystore file also with a graphical tool
echo -e "${GREEN}You can also use the graphical keystore-explorer (https://keystore-explorer.org/)${NC}"
echo -e "${GREEN}to view and check the keystore file.${NC}"

# Remind user to remove the local key and cert files used for building the keystore
echo -e "${RED}Keep in mind to remove the local key and cert files used for building the keystore!${NC}"

exit 0

