#!/bin/sh

ALGOS="RSA1024 RSA2048 ECCP256 ECCP384"

for ALGO in ${ALGOS}; do
  mkdir -p "${ALGO}"
  cd "${ALGO}"
  case "${ALGO}" in
    "RSA1024")
      openssl req -new -newkey rsa:1024 -nodes -out CA_CSR.csr -keyout CA_private_key.key -sha256 -subj "/CN=AuthenTrend/"
      ;;
    "RSA2048")
      openssl req -new -newkey rsa:2048 -nodes -out CA_CSR.csr -keyout CA_private_key.key -sha256 -subj "/CN=AuthenTrend/"
      ;;
    "ECCP256")
      openssl genpkey -algorithm EC -out CA_private_key.key -pkeyopt ec_paramgen_curve:P-256 -pkeyopt ec_param_enc:named_curve &&
      openssl req -new -sha256 -key CA_private_key.key -out CA_CSR.csr -subj "/CN=AuthenTrend/"
      ;;
    "ECCP384")
      openssl genpkey -algorithm EC -out CA_private_key.key -pkeyopt ec_paramgen_curve:P-384 -pkeyopt ec_param_enc:named_curve &&
      openssl req -new -sha256 -key CA_private_key.key -out CA_CSR.csr -subj "/CN=AuthenTrend/"
      ;;
  esac
  openssl x509 -signkey CA_private_key.key -days 90 -req -in CA_CSR.csr -out CA_certificate.arm -sha256 &&
  openssl x509 -req -days 90 -in CA_CSR.csr -CA CA_certificate.arm -CAkey CA_private_key.key -out CA_selfsigned_certificate.arm -set_serial 01 -sha256
  cd ..
done
