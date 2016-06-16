#Security Splunk FleetUnit
To install splunk security forwarding agents.  The Splunk Security forwarders drops an outputs.conf configuration and required certs to the coreos hosts in /opt/splunk/etc/system/local directory. A cert and ca cert is also required (please see: https://wiki.corp.adobe.com/display/saas/Sending+logs+to+Security+Splunk) these shoudl reside in the secrets s3 directory.

##Configuration Requirements
1. VPC peering w/ security splunk VPC to allow journald logs forwarding.
2. Security Splunk CA cert SSLCert and CertPassword
3. outputs.conf configuration
4. Fleetunits for forwarder and pipe service

##Format Certs to secrets.json parameter
get certs from https://wiki.corp.adobe.com/display/saas/Sending+logs+to+Security+Splunk
```
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' cert.pem
```

##How To enable in Ethos.
1. Add ncessary VPC peering parameters 
2. Include in your secrets.json the following config parameters get splunk security parameter values form https://wiki.corp.adobe.com/display/saas/Sending+logs+to+Security+Splunk (Format Certs to Secrets.json parameter)
```
"/splunk/SPLUNK_FORWARD_SERVER_LIST": "",
"/splunk/SPLUNK_SSLPASSWORD": "",
"/splunk/SPLUNK_ADOBECAAS_CERT": "-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----\n",
"/splunk/SPLUNK_CA": "-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----\n-----BEGIN EC PRIVATE KEY-----\n-----END EC PRIVATE KEY-----\n",
"environemtn/services": "splunk"
```


