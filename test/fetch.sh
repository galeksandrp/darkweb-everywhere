#!/bin/bash
# Run https-everywhere-checker for each changed ruleset
# This is run from test/travis.sh, but should work just as well without travis
# as long as $RULESETS_CHANGED is supplied.

RULETESTFOLDER="test/rules"

# Exclude those rulesets that do not exist.
for RULESET in $RULESETS_CHANGED; do
  # First check if the given ruleset actually exists
  if [ ! -f $RULESET ]; then
    echo >&2 "Skipped $RULESET; file not found."
    continue
  fi
  TO_BE_TESTED="$TO_BE_TESTED $RULESET"
done

if [ "$TO_BE_TESTED" ]; then
  # Do the actual test, using https-everywhere-checker.
  TOR=$(xmllint --xpath 'string(//ruleset/@platform)' $TO_BE_TESTED | grep 'mixedcontent')
  COMMAND='python'
  if [ "$TOR" ]; then
    service tor start
    sleep 10
    echo nameserver 127.0.0.1 > /etc/resolv.conf
    iptables -t nat -A OUTPUT -m owner --uid-owner $(sudo -u test id -u) -p tcp --syn -j REDIRECT --to-ports 9040
    COMMAND='sudo -u test python'
  fi
  OUTPUT_FILE=`mktemp`
  trap 'rm "$OUTPUT_FILE"' EXIT
  $COMMAND $RULETESTFOLDER/src/https_everywhere_checker/check_rules.py $RULETESTFOLDER/http.checker.config $TO_BE_TESTED 2>&1 | tee $OUTPUT_FILE
  # Unfortunately, no specific exit codes are available for connection
  # failures, so we catch those with grep.
  if [[ `cat $OUTPUT_FILE | grep ERROR | wc -l` -ge 1 ]]; then
    echo >&2 "Test URL test failed."
    exit 1
  fi
fi
echo >&2 "Test URL test succeeded."
