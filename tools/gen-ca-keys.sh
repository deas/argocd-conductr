#!/bin/sh

key=tls.key
crt=tls.crt
: ${subj:=/C=DE/ST=Hamburg/L=Hamburg/O=My Company/CN=My Root CA}
: ${cnf:=tls.cnf}

openssl genpkey -algorithm RSA -out ${key}
# -aes256 -pass pass:yourpassword

# Create a configuration file for the CA certificate
#cat <<EOT >"$cnf"
#[ req ]
#default_bits       = 2048
#efault_md         = sha256
#distinguished_name = req_distinguished_name
#x509_extensions    = v3_ca

#[ req_distinguished_name ]
#countryName                 = Country Name (2 letter code)
#countryName_default         = US
#stateOrProvinceName         = State or Province Name (full name)
#stateOrProvinceName_default = California
#localityName                = Locality Name (eg, city)
#localityName_default        = San Francisco
#organizationName            = Organization Name (eg, company)
#organizationName_default    = My Company
#commonName                  = Common Name (eg, fully qualified host name)
#commonName_default          = My Root CA

#[ v3_ca ]
#subjectKeyIdentifier=hash
#authorityKeyIdentifier=keyid:always,issuer:always
#basicConstraints = critical, CA:true
#keyUsage = critical, digitalSignature, cRLSign, keyCertSign
#EOT

# Generate a CSR and self-sign it to create the CA certificate
# -passin pass:yourpassword \
openssl req -new -x509 -days 3650 -key "${key}" -out "${crt}" -config "${cnf}" -subj "${subj}"

# openssl x509 -noout -text <ca.crt

# -n openshift-config -
kubectl create secret generic custom-ca --from-file=tls.crt=${crt} --from-file=tls.key=${key} --dry-run=client -o yaml
