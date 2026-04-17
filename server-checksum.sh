#!/bin/bash

echo "Checksum for certificate server.crt"
openssl x509 -in  server.crt -pubkey -noout -outform pem | sha256sum

echo "Checksum for key file server.key"
openssl pkey -in server.key -pubout -outform pem | sha256sum
