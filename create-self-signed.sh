#!/bin/bash
set -eu

openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -sha256 -days 3650 -nodes -subj "/C=DE/ST=Rheinland-Pfalz/L=Bingen/O=ITDudes/OU=Consulting/CN=idontlikemondays.itdudes.io"
