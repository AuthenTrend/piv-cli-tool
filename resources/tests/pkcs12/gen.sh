#!/bin/sh

ALGOS="RSA1024 RSA2048 ECCP256 ECCP384"

for ALGO in ${ALGOS}; do
  mkdir -p "${ALGO}"
  cd "${ALGO}"
  case "${ALGO}" in
    "RSA1024")
      openssl genrsa -out key.pem 1024
      ;;
    "RSA2048")
      openssl genrsa -out key.pem 2048
      ;;
    "ECCP256")
      openssl genpkey -algorithm EC -out key.pem -pkeyopt ec_paramgen_curve:P-256 -pkeyopt ec_param_enc:named_curve
      ;;
    "ECCP384")
      openssl genpkey -algorithm EC -out key.pem -pkeyopt ec_paramgen_curve:P-384 -pkeyopt ec_param_enc:named_curve
      ;;
  esac
  openssl req -new -sha256 -key key.pem -out csr.csr -subj "/CN=AuthenTrend/" &&
  openssl req -x509 -sha256 -days 3650 -key key.pem -in csr.csr -out certificate.pem &&
  openssl pkcs12 -export -out pkcs12.pfx -inkey key.pem -in certificate.pem -password pass:24469172
  cd ..
done
