#!/bin/bash

CMD=
READER=
SLOTS=
ALGORITHMS=
PIN_POLICIES=
TOUCH_POLICIES=
TEST_CASES=

source util.sh
source constants.sh

_help() {
  echo -e "\nUsage:"
  echo -e "\t$0 -c <CMD | BIN_PATH> -r <READER_NAME> -s <all | essential | SLOTS> [-a <all | ALGORITHMS> -p <all | essential | PIN_POLICIES> -o <all | TOUCH_POLICIES> -t <TEST_CASES>]\n"
  echo -e "\t-c\tCommand name which can be found in shell enviroment, or the full path of an executable binary file"
  echo -e "\t-r\tFull or partial reader name"
  echo -e "\t-s\tWhich slots to test, default is all, essential includes only "9a 9c 9d 9e""
  echo -e "\t-a\tAlgorithms for generating key, default is all except cases which starts from 20"
  echo -e "\t-p\tWhich PIN policies to test, default is essential, which includes\"never once always\""
  echo -e "\t-o\tWhich Touch policies to test, default is never"
  echo -e "\t-t\tWhich test cases to run, default runs all test cases"
  echo
  echo -e "Examples:"
  echo -e "\t$0 -c piv-cli-tool -r atkey -s essential -a \"ECCP256 ECCP384\" -t \"piv_testcase01 piv_testcase08\""
  echo -e "\t$0 -c piv-cli-tool -r atkey -s \"9a 9d\""
  echo -e "\t$0 -c piv-cli-tool -r atkey -s essential -a \"ECCP256\" -p essential -t \"piv_testcase12\""
  echo -e "\t$0 -c piv-cli-tool -r atkey -s essential -a \"ECCP256\" -p \"bioOnce bioAlways\" -o all -t \"piv_testcase12\""
  echo
}

while getopts ':c:r:s:a:p:o:t:h' opt; do
  case "$opt" in
    c)
      command -v ${OPTARG} > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        CMD=${OPTARG}
      elif [ -f "${OPTARG}" ]; then
        _print_err "${OPTARG}: Permission denied"
        exit 1
      else
        _print_err "Command '${OPTARG}' not found"
        exit 1
      fi
      ;;
    r)
      ${CMD} -r ${OPTARG} -a status > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        READER=${OPTARG}
      else
        _print_err "${OPTARG} not found"
        exit 1
      fi
      ;;
    s)
      case "${OPTARG}" in
        "all")
          SLOTS=${ALL_SLOTS}
          ;;
        "essential")
          SLOTS=${ESS_SLOTS}
          ;;
        *)
          DIFF_SLOTS=$(echo "${ALL_SLOTS} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -iu | tr '\n' ' ')
          UNKNOWN_SLOTS=$(echo "${DIFF_SLOTS} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -id | tr -d '[:space:]' | tr '\n' ' ')
          if [ "${UNKNOWN_SLOTS}" = "" ]; then
            SLOTS=${OPTARG}
          else
            _print_err "Slot(s) '${UNKNOWN_SLOTS}' not found"
            exit 1
          fi
          ;;
      esac
      ;;
    a)
      case "${OPTARG}" in
        "all")
          ;;
        *)
          DIFF_ALGOS=$(echo "${ALL_ALGORITHMS} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -u | tr '\n' ' ')
          UNKNOWN_ALGOS=$(echo "${DIFF_ALGOS} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -d | tr -d '[:space:]' | tr '\n' ' ')
          if [ "${UNKNOWN_ALGOS}" = "" ]; then
            ALGORITHMS=${OPTARG}
          else
            _print_err "Algorithm(s) '${UNKNOWN_ALGOS}' not found"
            exit 1
          fi
      esac
      ;;
    p)
      case "${OPTARG}" in
        "all")
          PIN_POLICIES=${ALL_PIN_POLICIES}
          ;;
        "essential")
          ;;
        *)
          DIFF_PIN_POLICIES=$(echo "${ALL_PIN_POLICIES} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -u | tr '\n' ' ')
          UNKNOWN_PIN_POLICIES=$(echo "${DIFF_PIN_POLICIES} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -d | tr -d '[:space:]' | tr '\n' ' ')
          if [ "${UNKNOWN_PIN_POLICIES}" = "" ]; then
            PIN_POLICIES=${OPTARG}
          else
            _print_err "PIN policy '${UNKNOWN_PIN_POLICIES}' not found"
            exit 1
          fi
      esac
      ;;
    o)
      case "${OPTARG}" in
        "all")
          TOUCH_POLICIES=${ALL_TOUCH_POLICIES}
          ;;
        *)
          DIFF_TOUCH_POLICIES=$(echo "${ALL_TOUCH_POLICIES} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -u | tr '\n' ' ')
          UNKNOWN_TOUCH_POLICIES=$(echo "${DIFF_TOUCH_POLICIES} ${OPTARG}" | sed 's/ /\n/g' | sort | uniq -d | tr -d '[:space:]' | tr '\n' ' ')
          if [ "${UNKNOWN_TOUCH_POLICIES}" = "" ]; then
            TOUCH_POLICIES=${OPTARG}
          else
            _print_err "Touch policy '${UNKNOWN_TOUCH_POLICIES}' not found"
            exit 1
          fi
      esac
      ;;
    t)
      TEST_CASES=${OPTARG}
      ;;
    h|:|?)
      _help
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [ "$CMD" = "" ] || [ "$READER" = "" ] || [ "$SLOTS" = "" ]; then
  _help
  exit 1
fi

source piv_test_cases.sh

if [ "${ALGORITHMS}" != "" ]; then
  TEST_ALGOS=${ALGORITHMS}
fi

if [ "${PIN_POLICIES}" != "" ]; then
  TEST_PIN_POLICIES=${PIN_POLICIES}
fi

if [ "${TOUCH_POLICIES}" != "" ]; then
  TEST_TOUCH_POLICIES=${TOUCH_POLICIES}
fi

ALL_TEST_CASES=$(declare -F | grep -e piv_testcase0 -e piv_testcase1 | awk -F' ' '{print $3}' | sort | tr '\n' ' ')
if [ "${TEST_CASES}" != "" ]; then
  DIFF_TEST_CASES=$(echo "${ALL_TEST_CASES} ${TEST_CASES}" | sed 's/ /\n/g' | sort | uniq -u | tr '\n' ' ')
  UNKNOWN_TEST_CASES=$(echo "${DIFF_TEST_CASES} ${TEST_CASES}" | sed 's/ /\n/g' | sort | uniq -d | tr -d '[:space:]' | tr '\n' ' ')
  if [ "${UNKNOWN_TEST_CASES}" != "" ]; then
    _print_err "Test case(s) '${UNKNOWN_TEST_CASES}' not found"
    exit 1
  fi
else
  TEST_CASES=${ALL_TEST_CASES}
fi

TEST_SLOTS=${SLOTS}
for x in ${TEST_CASES}; do
  $x
done
