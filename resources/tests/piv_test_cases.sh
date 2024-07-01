#!/bin/bash

source constants.sh

CUR_PIN=${DEF_PIN}
CUR_PUK=${DEF_PUK}
CUR_MGM_KEY=${DEF_MGM_KEY}
CUR_PIN_RETRIES=${DEF_PIN_RETRIES}
CUR_PUK_RETRIES=${DEF_PUK_RETRIES}
PROTECTED_MGM_ENABLED=0
PROTECTED_PIN_ENABLED=0
TEST_ALGOS=${ALL_ALGORITHMS}
TEST_SLOTS=${ALL_SLOTS}
TEST_PIN_POLICIES=${DEF_PIN_POLICIES}
TEST_TOUCH_POLICIES=${DEF_TOUCH_POLICIES}

_piv_get_status_properties() {
  PROP=()
  for x in $(seq $#); do
    PROP+=("${!x}")
  done

  RES=$(${CMD} -r ${READER} -a status)
  RET=
  PROP_NUM=${#PROP[@]}
  for x in $(seq 0 $(expr ${PROP_NUM} - 1)); do
    VAL=$(echo "${RES}" | grep "${PROP[x]}" | sed "s/${PROP[x]}//" | tr -d '\t')
    RET+="${VAL};"
  done
  echo "${RET}" | tr ';' '\n'
}

_piv_reset() {
  PIN_RETRIES=$1
  PUK_RETRIES=$2

  for x in $(seq ${PIN_RETRIES}); do
    ${CMD} -r ${READER} -a verify-pin --pin=${WRN_PIN}
  done
  for x in $(seq ${PUK_RETRIES}); do
    ${CMD} -r ${READER} -a unblock-pin --pin=${WRN_PUK} --new-pin=${WRN_PIN}
  done
  ${CMD} -r ${READER} -a reset
}

_piv_set_pin_puk_retries() {
  PIN_RETRIES=$1
  PUK_RETRIES=$2

  ${CMD} -r ${READER} -a verify-pin --pin=${CUR_PIN} -a pin-retries --pin-retries=${PIN_RETRIES} --puk-retries=${PUK_RETRIES}
}

_piv_change_pin_puk() {
  NEW_PIN=$1
  NEW_PUK=$2

  ${CMD} -r ${READER} -a change-pin --pin=${CUR_PIN} --new-pin=${NEW_PIN} &&
  ${CMD} -r ${READER} -a change-puk --pin=${CUR_PUK} --new-pin=${NEW_PUK}
}

_piv_verify_pin() {
  PIN=$1

  ${CMD} -r ${READER} -a verify-pin --pin=${PIN}
}

_piv_unblock_pin() {
  PUK=$1
  NEW_PIN=$2

  ${CMD} -r ${READER} -a unblock-pin --pin=${PUK} --new-pin=${NEW_PIN}
}

_piv_verify_mgm_key() {
  MGM_KEY=$1

  ${CMD} -r ${READER} -a verify-mgm-key --key=${MGM_KEY}
}

_change_mgm_key() {
  MGM_KEY=$1
  NEW_MGM_KEY=$2

  ${CMD} -r ${READER} -a verify-mgm-key -a set-mgm-key --key=${MGM_KEY} --new-key=${NEW_MGM_KEY}
}

_set_pin_protected_mgm_key() {
  ENABLED=$1
  PIN=$2
  MGM_KEY=$3

  ${CMD} -r ${READER} -a set-protected-mgm --enable=${ENABLED} --pin=${PIN} --key=${MGM_KEY}
}

_read_object() {
  TAG=$1

  ${CMD} -r ${READER} -a read-object --id=${TAG}
}

_write_object() {
  TAG=$1
  MGM_KEY=$2
  HEX=$3

  ${CMD} -r ${READER} -a write-object --id=${TAG} --key=${MGM_KEY} --input=- --format=hex < <(echo ${HEX})
}

_set_chuid() {
  MGM_KEY=$1
  ${CMD} -r ${READER} -a set-chuid --key=${MGM_KEY}
}

_generate_key() {
  SLOT=$1
  ALGO=$2
  MGM_KEY=$3

  ${CMD} -r ${READER} -a generate --slot=${SLOT} --algorithm=${ALGO} --key=${MGM_KEY}
}

_generate_selfsign_certificate() {
  SLOT=$1
  PIN=$2

  ${CMD} -r ${READER} -a verify-pin -a selfsign-certificate --slot=${SLOT} --pin=${PIN} --valid-days=365 --subject="/CN=${SLOT}/"
}

_generate_key_and_selfsign_certificate() {
  SLOT=$1
  ALGO=$2
  PIN=$3
  MGM_KEY=$4

  ${CMD} -r ${READER} -a verify-pin -a generate-selfsigned-certificate --slot=${SLOT} --algorithm=${ALGO} --pin=${PIN} --key=${MGM_KEY} --valid-days=365 --subject="/CN=${SLOT}/"
}

_verify_certificate() {
  SLOT=$1
  PIN=$2
  CERT=$3

  ${CMD} -r ${READER} -a verify-pin -a test-signature --slot=${SLOT} --pin=${PIN} < <(echo "${CERT}")
}

_import_certificate() {
  SLOT=$1
  MGM_KEY=$2
  CERT=$3

  ${CMD} -r ${READER} -a import-certificate --slot=${SLOT} --key=${MGM_KEY} < <(echo "${CERT}")
}

_read_certificate() {
  SLOT=$1

  ${CMD} -r ${READER} -a read-certificate --slot=${SLOT}
}

_delete_certificate() {
  SLOT=$1
  MGM_KEY=$2

  ${CMD} -r ${READER} -a delete-certificate --slot=${SLOT} --key=${MGM_KEY}
}

_delete_key() {
  SLOT=$1
  MGM_KEY=$2

  ${CMD} -r ${READER} -a delete-key --slot=${SLOT} --key=${MGM_KEY}
}

_generate_csr() {
  SLOT=$1
  PIN=$2

  ${CMD} -r ${READER} -a verify-pin -a request-certificate --slot=${SLOT} --pin=${PIN} --valid-days=365 --subject="/CN=${SLOT}/"
}

_generate_key_and_csr() {
  SLOT=$1
  ALGO=$2
  PIN=$3
  MGM_KEY=$4

  ${CMD} -r ${READER} -a verify-pin -a generate-csr --slot=${SLOT} --algorithm=${ALGO} --pin=${PIN} --key=${MGM_KEY} --valid-days=365 --subject="/CN=${SLOT}/"
}

_import_private_key() {
  SLOT=$1
  MGM_KEY=$2
  PRIKEY=$3

  ${CMD} -r ${READER} -a import-key --slot=${SLOT} --key=${MGM_KEY} < <(echo "${PRIKEY}")
}

_import_pkcs12() {
  SLOT=$1
  PIN=$2
  MGM_KEY=$3
  PASSWORD=$4
  FILE=$5
  ARGS=$6

  ${CMD} -r ${READER} -a verify-pin -a import-key -a import-certificate --slot=${SLOT} --pin=${PIN} --key=${MGM_KEY} --key-format=PKCS12 --password=${PASSWORD} --input=${FILE} ${ARGS}
}

_move_key() {
  FROM_SLOT=$1
  TO_SLOT=$2
  MGM_KEY=$3

  ${CMD} -r ${READER} -a move-key --slot=${FROM_SLOT} --to-slot=${TO_SLOT} --key=${MGM_KEY}
}

_verify_certificate_file_twice() {
  SLOT=$1
  PIN=$2
  FILE=$3
  VERIFY_PIN_TIMES=$4

  if [ ${VERIFY_PIN_TIMES} -eq 0 ]; then
    ${CMD} -r ${READER} -a test-signature -a test-signature --slot=${SLOT} --pin=${PIN} --input=${FILE}
  elif [ ${VERIFY_PIN_TIMES} -eq 1 ]; then
    ${CMD} -r ${READER} -a verify-pin -a test-signature -a test-signature --slot=${SLOT} --pin=${PIN} --input=${FILE}
  else
    ${CMD} -r ${READER} -a verify-pin -a test-signature -a verify-pin -a test-signature --slot=${SLOT} --pin=${PIN} --input=${FILE}
  fi
}

_bio_verify_certificate_file_twice() {
  SLOT=$1
  FILE=$2
  VERIFY_BIO_TIMES=$3

  if [ ${VERIFY_BIO_TIMES} -eq 0 ]; then
    ${CMD} -r ${READER} -a test-signature -a test-signature --slot=${SLOT} --input=${FILE}
  elif [ ${VERIFY_BIO_TIMES} -eq 1 ]; then
    ${CMD} -r ${READER} -a verify-bio -a test-signature -a test-signature --slot=${SLOT} --input=${FILE}
  else
    ${CMD} -r ${READER} -a verify-bio -a test-signature -a verify-bio -a test-signature --slot=${SLOT} --input=${FILE}
  fi
}

_set_bio_protected_pin() {
  ENABLED=$1
  PIN=$2

  ${CMD} -r ${READER} -a set-protected-pin --enable=${ENABLED} --pin=${PIN}
}

_test_decipher() {
  SLOT=$1
  PIN=$2
  FILE=$3

  ${CMD} -r ${READER} -a verify-pin -a test-decipher --slot=${SLOT} --pin=${PIN} --input=${FILE}
}

piv_testcase01() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tReset test"
  echo -e "#\n"

  RES=$(_piv_get_status_properties "PIN tries left:" "PUK tries left:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")

  PIN_RETRIES=${CUR_PIN_RETRIES}
  PUK_RETRIES=${CUR_PUK_RETRIES}
  if [ ${#VALUES[@]} -eq 2 ]; then
    PIN_RETRIES=${VALUES[0]}
    PUK_RETRIES=${VALUES[1]}
  fi
  _piv_reset ${PIN_RETRIES} ${PUK_RETRIES} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (failed to reset PIV)\n"
    exit 1
  fi
}

piv_testcase02() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tPIN/PUK retries changing test"
  echo -e "#\n"

  PIN_RETRIES=$(expr ${CUR_PIN_RETRIES} + 1)
  PUK_RETRIES=$(expr ${CUR_PUK_RETRIES} + 1)
  _piv_set_pin_puk_retries ${PIN_RETRIES} ${PUK_RETRIES} > /dev/null 2>&1
  RES=$(_piv_get_status_properties "PIN tries left:" "PUK tries left:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")
  if [ ${#VALUES[@]} -ne 2 ] || [ ${VALUES[0]} -ne ${PIN_RETRIES} ] || [ ${VALUES[1]} -ne ${PUK_RETRIES} ]; then
    echo -e "Result: \tFAIL (PIN/PUK retries not found)\n"
    exit 1
  fi

  CUR_PIN_RETRIES=${PIN_RETRIES}
  CUR_PUK_RETRIES=${PUK_RETRIES}
  _piv_reset ${CUR_PIN_RETRIES} ${CUR_PUK_RETRIES} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    CUR_PIN_RETRIES=${DEF_PIN_RETRIES}
    CUR_PUK_RETRIES=${DEF_PUK_RETRIES}
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (failed to reset PIV)\n"
    exit 1
  fi
}

piv_testcase03() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tPIN/PUK test"
  echo -e "#\n"

  NEW_PIN="654321"
  NEW_PUK="87654321"
  _piv_change_pin_puk ${NEW_PIN} ${NEW_PUK} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to change PIN/PUK)\n"
    exit 1
  fi

  CUR_PIN=${NEW_PIN}
  CUR_PUK=${NEW_PUK}
  _piv_verify_pin ${CUR_PIN} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to verify PIN)\n"
    exit 1
  fi

  NEW_PIN="111111"
  _piv_unblock_pin ${CUR_PUK} ${NEW_PIN} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to unblock PIN)\n"
    exit 1
  fi

  CUR_PIN=${NEW_PIN}
  _piv_verify_pin ${CUR_PIN} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (failed to verify PIN)\n"
    exit 1
  fi
}

piv_testcase04() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tManagement key test"
  echo -e "#\n"

  _piv_verify_mgm_key ${CUR_MGM_KEY} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to verify management key)\n"
    exit 1
  fi

  NEW_MGM_KEY="080706050403020108070605040302010807060504030201"
  _change_mgm_key ${CUR_MGM_KEY} ${NEW_MGM_KEY} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to change management key)\n"
    exit 1
  fi

  CUR_MGM_KEY=${NEW_MGM_KEY}
  _piv_verify_mgm_key ${CUR_MGM_KEY} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (failed to verify management key)\n"
    exit 1
  fi
}

piv_testcase05() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tPIN-protected management key test"
  echo -e "#\n"

  ENABLED=1
  _set_pin_protected_mgm_key ${ENABLED} ${WRN_PIN} ${CUR_MGM_KEY} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to enable PIN-protected management key)\n"
    exit 1
  fi
  PROTECTED_MGM_ENABLED=${ENABLED}

  RES=$(_piv_get_status_properties "PIN-protected:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")
  if [ "${VALUES[0]}" != "1" ]; then
    echo -e "Result: \tFAIL (status is not PIN-protected)\n"
    exit 1
  fi

  ENABLED=0
  _set_pin_protected_mgm_key ${ENABLED} ${CUR_PIN} ${WRN_MGM_KEY} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to disable PIN-protected management key)\n"
    exit 1
  fi
  PROTECTED_MGM_ENABLED=${ENABLED}

  RES=$(_piv_get_status_properties "PIN-protected:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")
  if [ "${VALUES[0]}" = "0" ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (status is PIN-protected)\n"
    exit 1
  fi
}

piv_testcase06() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tR/W admin data test"
  echo -e "#\n"

  _read_object ${TAG_ADMIN_DATA} | grep 810100 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to read object ${TAG_ADMIN_DATA})\n"
    exit 1
  fi

  HEX="8003810102"
  _write_object ${TAG_ADMIN_DATA} ${CUR_MGM_KEY} ${HEX} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to write object ${TAG_ADMIN_DATA})\n"
    exit 1
  fi

  _read_object ${TAG_ADMIN_DATA} | grep 810102 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to read object ${TAG_ADMIN_DATA})\n"
    exit 1
  fi

  RES=$(_piv_get_status_properties "PIN-protected:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")
  if [ "${VALUES[0]}" != "1" ]; then
    echo -e "Result: \tFAIL (status is not PIN-protected)\n"
    exit 1
  fi
  PROTECTED_MGM_ENABLED=1

  HEX="8003810100"
  _write_object ${TAG_ADMIN_DATA} ${CUR_MGM_KEY} ${HEX} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to write object ${TAG_ADMIN_DATA})\n"
    exit 1
  fi

  _read_object ${TAG_ADMIN_DATA} | grep 810100 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to read object ${TAG_ADMIN_DATA})\n"
    exit 1
  fi

  RES=$(_piv_get_status_properties "PIN-protected:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")
  if [ "${VALUES[0]}" = "0" ]; then
    PROTECTED_MGM_ENABLED=0
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (status is PIN-protected)\n"
    exit 1
  fi
}

piv_testcase07() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tCHUID test"
  echo -e "#\n"

  _set_chuid ${CUR_MGM_KEY} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to set CHUID)\n"
    exit 1
  fi

  CHUID=$(_read_object ${TAG_CHUID})
  RES=$(_piv_get_status_properties "CHUID:")
  VALUES=()
  while read line; do
      VALUES+=("$line")
  done < <(echo "${RES}")
  if [ "${CHUID}" = "${VALUES[0]}" ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (different CHUID)\n"
    exit 1
  fi
}

piv_testcase08() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tSelf-signed certificate generating test"
  echo -e "#\n"

  for ALGO in ${TEST_ALGOS}; do
    ROUND=0
    for SLOT in ${TEST_SLOTS}; do
      echo "Generating with algorithm ${ALGO} on slot ${SLOT}"
      CERT=
      ROUND=$(expr ${ROUND} + 1)
      if [ $(expr ${ROUND} % 2) -eq 0 ]; then
        PUBKEY=$(_generate_key ${SLOT} ${ALGO} ${CUR_MGM_KEY} 2>&-)
        CERT=$(_generate_selfsign_certificate ${SLOT} ${CUR_PIN} < <(echo "${PUBKEY}") 2>&-)
      else
        OUT=$(_generate_key_and_selfsign_certificate ${SLOT} ${ALGO} ${CUR_PIN} ${CUR_MGM_KEY} 2>&1)
        BEGIN_LINE=$(echo "${OUT}" | awk '/-----BEGIN CERTIFICATE-----/{print NR}')
        END_LINE=$(echo "${OUT}" | awk '/-----END CERTIFICATE-----/{print NR}')
        CERT=$(echo "${OUT}" | head -n ${END_LINE} | tail -n $(expr ${END_LINE} - ${BEGIN_LINE} + 1) 2>&-)
      fi
      if [ "${CERT}" = "" ]; then
        echo -e "Result: \tFAIL (failed to generate key or self-signed certificate)\n"
        exit 1
      fi

      _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to verify certificate)\n"
        exit 1
      fi

      _import_certificate ${SLOT} ${CUR_MGM_KEY} "${CERT}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to import certificate)\n"
        exit 1
      fi

      RES=$(_read_certificate ${SLOT})
      if [ "${RES}" != "${CERT}" ]; then
        echo -e "Result: \tFAIL (different certificate)\n"
        exit 1
      fi
    done
    echo
  done

  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL\n"
    exit 1
  fi
}

piv_testcase09() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tCertificate/Key deleting test"
  echo -e "#\n"

  for SLOT in ${TEST_SLOTS}; do
    echo "Testing slot ${SLOT}"
    CERT=$(_read_certificate ${SLOT})
    _delete_certificate ${SLOT} ${CUR_MGM_KEY} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo -e "Result: \tFAIL (failed to delete certificate)\n"
      exit 1
    fi

    _read_certificate ${SLOT} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "Result: \tFAIL (reading certificate shouldn't be success)\n"
      exit 1
    fi

    _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo -e "Result: \tFAIL (failed to verify certificate)\n"
      exit 1
    fi

    _delete_key ${SLOT} ${CUR_MGM_KEY} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo -e "Result: \tFAIL (failed to delete key)\n"
      exit 1
    fi

    _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e "Result: \tFAIL (verifying certificate shouldn't be success)\n"
      exit 1
    fi
  done
  echo

  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL\n"
    exit 1
  fi
}

piv_testcase10() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tCSR test"
  echo -e "#\n"

  for ALGO in ${TEST_ALGOS}; do
    ROUND=0
    for SLOT in ${TEST_SLOTS}; do
      echo "Testing slot ${SLOT} with algorithm ${ALGO}"
      CSR=
      ROUND=$(expr ${ROUND} + 1)
      if [ $(expr ${ROUND} % 2) -eq 0 ]; then
        PUBKEY=$(_generate_key ${SLOT} ${ALGO} ${CUR_MGM_KEY} 2>&-)
        CSR=$(_generate_csr ${SLOT} ${CUR_PIN} < <(echo "${PUBKEY}") 2>&-)
      else
        OUT=$(_generate_key_and_csr ${SLOT} ${ALGO} ${CUR_PIN} ${CUR_MGM_KEY} 2>&1)
        BEGIN_LINE=$(echo "${OUT}" | awk '/-----BEGIN CERTIFICATE REQUEST-----/{print NR}')
        END_LINE=$(echo "${OUT}" | awk '/-----END CERTIFICATE REQUEST-----/{print NR}')
        CSR=$(echo "${OUT}" | head -n ${END_LINE} | tail -n $(expr ${END_LINE} - ${BEGIN_LINE} + 1) 2>&-)
      fi
      if [ "${CSR}" = "" ]; then
        echo -e "Result: \tFAIL (failed to generate key or csr)\n"
        exit 1
      fi

      CERT=$(echo "${CSR}" | openssl x509 -req -days 365 -CA ca/${ALGO}/CA_certificate.arm -CAkey ca/${ALGO}/CA_private_key.key -set_serial 01 -sha256 2>&-)
      _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to verify certificate)\n"
        exit 1
      fi

      PRIKEY=$(cat ca/${ALGO}/CA_private_key.key)
      _import_private_key ${SLOT} ${CUR_MGM_KEY} "${PRIKEY}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to import ca private key)\n"
        exit 1
      fi

      CERT=$(cat ca/${ALGO}/CA_selfsigned_certificate.arm)
      _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to verify ca self-signed certificate)\n"
        exit 1
      fi
    done
    echo
  done

  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL\n"
    exit 1
  fi
}

piv_testcase11() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tPKCS12 file importing test"
  echo -e "#\n"

  SLOTS=()
  for x in ${TEST_SLOTS}; do
    SLOTS+=("$x")
  done
  SLOTS_NUM=${#SLOTS[@]}
  for ALGO in ${TEST_ALGOS}; do
    for i in $(seq 0 $(expr ${SLOTS_NUM} - 1)); do
      SLOT=${SLOTS[i]}
      echo "Testing slot ${SLOT} with algorithm ${ALGO}"
      _import_pkcs12 ${SLOT} ${CUR_PIN} ${CUR_MGM_KEY} 24469172 pkcs12/${ALGO}/pkcs12.pfx > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to import pkcs12 file)\n"
        exit 1
      fi

      CERT=$(_read_certificate ${SLOT})
      _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to verify certificate)\n"
        exit 1
      fi

      VERIFY_PIN_TIMES=1
      _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
      RES=$?
      if [ "${SLOT}" = "9c" ]; then
        if [ ${RES} -eq 0 ]; then
          echo -e "Result: \tFAIL (double verifying certificate with one verify-pin shouldn't be success on slot ${SLOT})\n"
          exit 1
        fi
        VERIFY_PIN_TIMES=2
        _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
        RES=$?
      fi
      if [ ${RES} -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to double verify certificate for slot ${SLOT})\n"
        exit 1
      fi

      _test_decipher ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo -e "Result: \tFAIL (failed to test key exchange/decryption)\n"
        exit 1
      fi

      last_i=$(expr ${SLOTS_NUM} - 1)
      if [ $i -lt ${last_i} ]; then
        next=$(expr $i + 1)
        NEXT_SLOT=${SLOTS[next]}
        _move_key ${SLOT} ${NEXT_SLOT} ${CUR_MGM_KEY} > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo -e "Result: \tFAIL (failed to move key)\n"
          exit 1
        fi

        _verify_certificate ${SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          echo -e "Result: \tFAIL (verifying certificate shouldn't be success)\n"
          exit 1
        fi

        _verify_certificate ${NEXT_SLOT} ${CUR_PIN} "${CERT}" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo -e "Result: \tFAIL (failed to verify certificate)\n"
          exit 1
        fi
      fi
    done
    echo
  done

  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL\n"
    exit 1
  fi
}

piv_testcase12() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tPIN/Touch policy test"
  echo -e "# Making sure at least one fingerprint has been enrolled and the finger is placed on the sensor if PIN/Touch policy needs the finger"
  echo -e "#\n"

  ALGO=$(echo "${TEST_ALGOS}" | awk -F' ' '{print $1}')
  for SLOT in ${TEST_SLOTS}; do
    for PIN_POLICY in ${TEST_PIN_POLICIES}; do
      for TOUCH_POLICY in ${TEST_TOUCH_POLICIES}; do
        echo "Testing slot ${SLOT} with algorithm ${ALGO}, PIN policy ${PIN_POLICY} and Touch policy ${TOUCH_POLICY}"
        _import_pkcs12 ${SLOT} ${CUR_PIN} ${CUR_MGM_KEY} 24469172 pkcs12/${ALGO}/pkcs12.pfx "--pin-policy=${PIN_POLICY} --touch-policy=${TOUCH_POLICY}" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo -e "Result: \tFAIL (failed to import pkcs12 file)\n"
          exit 1
        fi

        RES=
        case "${PIN_POLICY}" in
          "never")
            VERIFY_PIN_TIMES=0
            _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
            RES=$?
            ;;
          "once")
            VERIFY_PIN_TIMES=0
            _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
            RES1=$?
            VERIFY_PIN_TIMES=1
            _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
            RES2=$?
            test ${RES1} -ne 0 -a ${RES2} -eq 0
            RES=$?
            ;;
          "always")
            VERIFY_PIN_TIMES=1
            _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
            RES1=$?
            VERIFY_PIN_TIMES=2
            _verify_certificate_file_twice ${SLOT} ${CUR_PIN} pkcs12/${ALGO}/certificate.pem ${VERIFY_PIN_TIMES} > /dev/null 2>&1
            RES2=$?
            test ${RES1} -ne 0 -a ${RES2} -eq 0
            RES=$?
            ;;
          "bioOnce")
            VERIFY_BIO_TIMES=0
            _bio_verify_certificate_file_twice ${SLOT} pkcs12/${ALGO}/certificate.pem ${VERIFY_BIO_TIMES} > /dev/null 2>&1
            RES1=$?
            VERIFY_BIO_TIMES=1
            _bio_verify_certificate_file_twice ${SLOT} pkcs12/${ALGO}/certificate.pem ${VERIFY_BIO_TIMES} > /dev/null 2>&1
            RES2=$?
            test ${RES1} -ne 0 -a ${RES2} -eq 0
            RES=$?
            ;;
          "bioAlways")
            VERIFY_BIO_TIMES=1
            _bio_verify_certificate_file_twice ${SLOT} pkcs12/${ALGO}/certificate.pem ${VERIFY_BIO_TIMES} > /dev/null 2>&1
            RES1=$?
            VERIFY_BIO_TIMES=2
            _bio_verify_certificate_file_twice ${SLOT} pkcs12/${ALGO}/certificate.pem ${VERIFY_BIO_TIMES} > /dev/null 2>&1
            RES2=$?
            test ${RES1} -ne 0 -a ${RES2} -eq 0
            RES=$?
            ;;
          *)
            echo -e "Result: \tFAIL (unknown PIN policy ${PIN_POLICY})\n"
            exit 1
        esac

        if [ ${RES} -ne 0 ]; then
          echo -e "Result: \tFAIL (failed to verify PIN/Touch policy)\n"
          exit 1
        fi
      done
      echo
    done
    echo
  done

  if [ $? -eq 0 ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL\n"
    exit 1
  fi
}

# Biometrics are required starting with Case 20
piv_testcase20() {
  echo -e "\n#"
  echo -e "# ${FUNCNAME}: \tBio-protected PIN setting test"
  echo -e "#\n"

  ENABLE=1
  _set_bio_protected_pin ${ENABLE} ${CUR_PIN} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to enable Bio-protected PIN)\n"
    exit 1
  fi
  PROTECTED_PIN_ENABLED=${ENABLED}

  RES=$(_piv_get_status_properties "Bio-for-pin-protected:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")
  if [ "${VALUES[0]}" != "1" ]; then
    echo -e "Result: \tFAIL (status is not Bio-protected)\n"
    exit 1
  fi

  ENABLE=0
  _set_bio_protected_pin ${ENABLE} ${CUR_PIN} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "Result: \tFAIL (failed to disable Bio-protected PIN)\n"
    exit 1
  fi
  PROTECTED_PIN_ENABLED=${ENABLED}

  RES=$(_piv_get_status_properties "Bio-for-pin-protected:")
  VALUES=()
  while read line; do
    if [[ $line =~ ^[0-9]+$ ]]; then
      VALUES+=("$line")
    fi
  done < <(echo "${RES}")

  if [ "${VALUES[0]}" = "0" ]; then
    echo -e "Result: \tPASS\n"
  else
    echo -e "Result: \tFAIL (status is Bio-protected)\n"
    exit 1
  fi
}
