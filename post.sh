#!/usr/bin/env bash

# exit when any command fails
set -e

TIMEFORMAT="Processed in %3lR"
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/config/config.env"
source "$SCRIPT_DIR/bin/color"
export PATH="$SCRIPT_DIR/bin:$PATH"
version=$(cat $SCRIPT_DIR/version)
echo -e $UND"Usenet posting script $version"$DEF

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
nvm use lts/gallium

usage=$blu"
Usage: $(basename "$0") -p <usenet provider> -d <dir to upload> -e <true|false (optional)>
Escape special characters in names if necessary, e.g. brackets: \[testdirectory\]
Use double quotes if the directory has spaces, e.g. \"This is a test directory\"
  -h                 - This help
  
  Mandatory parameters:
  -p <provider>      - Usenet provider name, e.g. blocknews, eweka, newshosting
  -d <dir to upload> - Directory to upload containing the rar/par2 files
  
  Optional parameters:
  -e <true|false>    - Embed the password generated during the packing step as a meta
                       element in the nzbs after the upload is done (default false)
"$DEF

while getopts ":hp:d:e:" opt; do
  case "$opt" in
  h)
    echo -e "$usage"
    exit
    ;;
  p) provider="$OPTARG" ;;
  d) directory="$OPTARG" ;;
  e) embedpassword="$OPTARG" ;;
  :)
    printf $red"Missing argument for -%s\n"$DEF "$OPTARG"
    echo -e "$usage"
    exit 1
    ;;
  esac
done

# mandatory arguments
if [[ -z "$provider" ]] || [[ -z "$directory" ]]; then
  echo -e $red"Arguments -p and -d must be provided"$DEF
  echo -e "$usage"
  exit 1
fi

json_conf="$SCRIPT_DIR/config/nyuu-$provider.json"
if [[ ! -f "$json_conf" ]]; then
  echo -e $red"Missing $json_conf"$DEF
  exit 1
fi

if [[ ! -d "$directory" ]]; then
  echo -e $red"Missing directory: $directory"$DEF
  exit 1
fi

[[ "$embedpassword" == true ]] || embedpassword=false

parentdir=$(dirname "$directory")
directory=$(basename "$directory")
cd "$parentdir"

filename=$(basename "$(ls "$directory"/*.par2 | head -1)" | cut -d. -f1) #get the par2 filename
nzbfile="$filename.nzb"
nzbfile2="$filename-file0.nzb"
zipfile="$filename.zip"

files=$(ls -1 "$directory" | wc -l)
rarsize=$(du -ach "$directory"/*.rar | tail -1 | cut -f 1)
chars=${#files} # count the characters
if (($chars == 1)); then
  filenum=$(printf "%01d" 0)
fi
if (($chars == 2)); then
  filenum=$(printf "%02d" 0)
fi
if (($chars == 3)); then
  filenum=$(printf "%03d" 0)
fi
if (($chars == 4)); then
  filenum=$(printf "%04d" 0)
fi

post_func() {
  if [[ "$RANDOMIZE_POSTER" == true ]]; then
    name=$(cat /dev/urandom | tr -dc 'a-z' | head -c 8)
    user=$(cat /dev/urandom | tr -dc 'a-z' | head -c 8)
    domain=$(cat /dev/urandom | tr -dc 'a-z' | head -c 8)
    tld=$(cat /dev/urandom | tr -dc 'a-z' | head -c 3)
    poster="$name <$user@$domain.$tld>"
  else
    poster=$(cat "$json_conf" | json "from")
  fi

  echo "\
Posting directory: '$directory' with $files files 
On $provider at server $(cat "$json_conf" | json "host")
Newsgroups: $NEWSGROUPS
Will generate NZBs: $nzbfile $nzbfile2
Embed password in nzb: $embedpassword
Randomize poster: $RANDOMIZE_POSTER
From: $poster
"
  echo "Posting in 5 sec, ctrl-c to abort."
  sleep 5

  set -x
  nyuu "$directory" -r -O -o "$nzbfile" \
    --subject "$directory - \"{filename}\" [{0filenum}/{files}] ({part}/{parts})" \
    --comment "$directory" --config "$json_conf" --groups $NEWSGROUPS --from "$poster" --progress stderrx
  nyuu "$nzbfile" -O -o "$nzbfile2" \
    --subject "$directory - \"{filename}\" [$filenum/$files] ({part}/{parts})" \
    --comment "$directory" --config "$json_conf" --groups $NEWSGROUPS --from "$poster" --progress stderrx
  set +x
}

# output of shell script to console and file https://stackoverflow.com/a/43502562, append to the log file
post_func > >(tee -a "$directory.log") 2>&1

sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' -i "$directory.log" # remove ansi codes https://stackoverflow.com/a/51141872/3663357
sed 's/^Posted.*\[INFO\]/\[INFO\]/' -i "$directory.log"   # remove the progress % strings

if [[ "$embedpassword == true" ]]; then
  echo -e $grn$BLD"Embedding password into $nzbfile and $nzbfile2\n"$DEF
  password=$(grep 'Password: ' "$directory.txt" | cut -d ' ' -f2)
  sed '/^<nzb.*/a\\t<head>\n\t\t<meta type="password">'$password'</meta>\n\t</head>' -i "$nzbfile"
  sed '/^<nzb.*/a\\t<head>\n\t\t<meta type="password">'$password'</meta>\n\t</head>' -i "$nzbfile2"
fi

zip "$zipfile" "$nzbfile"
# mv "$nzbfile" "$directory"/
# mv "$nzbfile2" "$directory"/
# mv "$zipfile" "$directory"/
# mv "$directory.log" "$directory"/

echo -e $blu$BLD"
$nzbfile
$nzbfile2
$zipfile
$directory.log
were created in: $parentdir
"$DEF

echo -e $BLD"Posting done"$DEF
