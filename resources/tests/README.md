
## PIV CLI Tool Test Script

This script doesn't automatically test biometrics required cases.

### macOS/Linux

```
./piv_cli_test.sh -h
```

### Windows

```
./piv_cli_test.ps1 -h
```

### Generating Private CA and Certificates

1. Create a private certificate authority (CA) and a certificate for it.
```
openssl req -new -newkey rsa:2048 -nodes -out CA_CSR.csr -keyout CA_private_key.key -sha256
```

2. Create a certificate for your private CA. This step creates a certificate (.arm) that you can use to sign your CSR.
```
openssl x509 -signkey CA_private_key.key -days 90 -req -in CA_CSR.csr -out CA_certificate.arm -sha256
```

3. Use the CA certificate to sign the certificate signing request that you created in Creating private keys and certificates.
```
openssl x509 -req -days 90 -in CSR.csr -CA CA_certificate.arm -CAkey CA_private_key.key -out certificate.arm -set_serial 01 -sha256
```
 * Replace CSR.csr with CA_CSR.csr to create a self-signed certificate

### Generating PKCS12(.p12, .pfx) file

1. Generate 2048-bit RSA/EC P-256 private key  
```
openssl genrsa -out key.pem 2048
```
```
openssl genpkey -algorithm EC -out key.pem -pkeyopt ec_paramgen_curve:P-256 -pkeyopt ec_param_enc:named_curve
```
2. Generate a Certificate Signing Request  
```
openssl req -new -sha256 -key key.pem -out csr.csr
```
3. Generate a self-signed x509 certificate
```
openssl req -x509 -sha256 -days 365 -key key.pem -in csr.csr -out certificate.pem
```
4. Create PKCS12 file
```
openssl pkcs12 -export -out pkcs12.pfx -inkey key.pem -in certificate.pem
```
&nbsp;&nbsp;&nbsp;&nbsp;Or specify the encryption algorithm for the private key and certificates.
```
openssl pkcs12 -export -out pkcs12.pfx -inkey key.pem -in certificate.pem -keypbe PBE-SHA1-RC2-40 -certpbe PBE-SHA1-RC2-40
```
