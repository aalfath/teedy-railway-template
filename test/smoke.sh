#!/bin/sh
# Smoke test for a Teedy deploy: login as admin, create a document, upload an image,
# wait for OCR, and find the document by a word that is only in the image.
# Usage: BASE=https://host PASS=... IMG=ocr.png [MODE=create|check] sh smoke.sh
set -eu
B=${BASE%/}; J=$(mktemp); C=$(mktemp)
curl -sf -c "$C" -X POST "$B/api/user/login" -d username=admin --data-urlencode "password=$PASS" -d remember=true >/dev/null && echo "login ok"
if [ "${MODE:-create}" = create ]; then
  DOC=$(curl -sf -b "$C" -X PUT "$B/api/document" -d title=SmokeDoc -d language=eng | sed 's/.*"id":"\([^"]*\)".*/\1/')
  echo "document $DOC"
  curl -sf -b "$C" -X PUT "$B/api/file" -F "id=$DOC" -F "file=@$IMG;type=image/png" && echo " <- upload ok"
fi
i=0
while [ $i -lt 40 ]; do
  R=$(curl -sf -b "$C" "$B/api/document/list?search=ZEBRAFOXTROT")
  case "$R" in *SmokeDoc*) echo "OCR search hit after ${i}x3s"; break;; esac
  i=$((i+1)); sleep 3
done
[ $i -lt 40 ] || { echo "OCR search: no hit"; echo "$R"; exit 1; }
curl -sf -b "$C" "$B/api/app" ; echo
