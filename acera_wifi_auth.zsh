#!/usr/bin/env zsh
setopt nomonitor

# Default output
function message() {
  echo $@ >&2
}

function indicate() {
  process=$!
  message=$1
  spinner=('.' 'o' 'O' 'o')
  success='✔'
  error='✗'
  while kill -0 $process 2> /dev/null; do
    for i in $spinner; do
      echo -ne "\r$i $message"
      sleep 0.2
    done
  done
  wait $process
  exitcode=$?
  [[ $exitcode == 0 ]] \
    && echo -ne "\r$success $message" \
    || echo -ne "\r$error $message"
  return $exitcode
}

# Secret keys
authfile=~/.acerarc
tmpfile=$(mktemp)
target="cgi2xml.cgi"

# Check vars
[[ -e $authfile ]] && source $authfile || message 'missing ~/.kcgrc'
[[ -z $param_id ]] && () { message 'missing $param_id'; exit 1 }
[[ -z $param_pass ]] && () { message 'missing $param_pass'; exit 2 }

# Access endpoint
curl $endpoint -o $tmpfile 2>/dev/null &
# indicate "Access to ${endpoint}... "
indicate "Endpoint... "
if [[ $? == 0 ]]; then
  # Already authed
  cat $tmpfile | grep '<p>WiFi and Internet access is successful</p>' >/dev/null 2>&1
  if [[ $? == 0 ]]; then
    message 'Already authed!'
    exit 0
  else
    message "OK!"
  fi
else
  message "Error!"
  exit 3
fi

# Call endpoint
param_pass=$(echo $param_pass|base64 -d)
param_secret=$(cat $tmpfile \
  |grep '^<input type="hidden"' \
  |sed 's/.*name="\([^"]\+\)" value="\([^"]\+\)".*/\1=\2/g' \
  |tr '\n' '&')
  curl "${endpoint}/${target}?${param_secret}ID=${param_id}&PWD=${param_pass}" >/dev/null 2>&1 &
  indicate "Authentification... "
  if [[ $? == 0 ]]; then
    message "OK!"
  else
    message "Error!"
    exit 3
  fi

# clean up
rm $tmpfile

