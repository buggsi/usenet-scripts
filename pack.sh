#!/usr/bin/env bash

# exit when any command fails
set -e

TIMEFORMAT="Processed in %3lR"
SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/config/config.env"
source "$SCRIPT_DIR/bin/color"
export PATH="$SCRIPT_DIR/bin:$PATH"
version=$(cat $SCRIPT_DIR/version)
echo -e $UND"Packing script $version"$DEF

usage=$blu"
Usage: $(basename "$0") -i <input dir> -o <output dir> -p <pack dir (optional)> -t <threads (optional)>
Escape special characters in names if necessary, e.g. brackets: \[testdirectory\]
Use double quotes if the directory has spaces, e.g. \"This is a test directory\"
  -h              - This help
  -i <input dir>  - Input directory or file to pack
  -o <output dir> - Output directory where the packed files will be written
  -p <pack dir>   - Packing directory where the project (packed files, txt, nzbs) will be
                    (optional, default '<current dir>/packing')
  -t <threads>    - CPU threads (optional, default = maximum threads - 2)
"$DEF

while getopts ":hi:o:p:t:" opt; do
    case "$opt" in
    h)
        echo -e "$usage"
        exit
        ;;
    i) input="$OPTARG" ;;
    o) output="$OPTARG" ;;
    p) packdir="$OPTARG" ;;
    t) threads="$OPTARG" ;;
    :)
        printf $red"missing argument for -%s\n"$DEF "$OPTARG"
        echo -e "$usage"
        exit 1
        ;;
    esac
done

# mandatory arguments
if [[ -z "$input" ]] || [[ -z "$output" ]]; then
    echo -e $red"Arguments -i and -o must be provided"$DEF
    echo -e "$usage"
    exit 1
fi

if [[ ! -e "$input" ]]; then
    echo -e $red"$input is not valid or doesn't exist"$DEF
    exit 1
fi

if [[ -z "$threads" ]]; then
    threads=$(expr $(nproc) - 2)
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
nvm use lts/gallium

if (($LENGTH_FILE < 6)) || (($LENGTH_PASSWORD < 6)); then
    echo "Random length for filename or password should be > 6, change it in the config.env file."
    exit 1
fi

# generate random chars for filename and password
FILENAME="$FILENAME_PREFIX"$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $LENGTH_FILE | head -n 1)
PASSWORD="$PASSWORD_PREFIX"$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $LENGTH_PASSWORD | head -n 1)

input_basename=$(basename "$input")
input_dirname=$(dirname "$input")
# input_realpath=$(realpath "$input")
# output_basename=$(basename "$output")
# output_dirname=$(dirname "$output")
# output_realpath=$(realpath "$output")

if [[ -z $packdir ]]; then
    workdir="packing"
else
    workdir=$(realpath "$packdir") # realpath removes any trailing slashes
fi
mkdir -p "$workdir/$output"

# write the filename/password to a file, so we don't lose it!
echo Filename: $FILENAME >"$workdir/$output.txt"
echo Password: $PASSWORD >>"$workdir/$output.txt"
echo Input file/dir: "$input_basename" >>"$workdir/$output.txt"
echo Output dir: "$output" >>"$workdir/$output.txt"
cat "$workdir/$output.txt"

# do the work from the parent dir of the input file/dir
cd "$input_dirname"

rm -f "$workdir/$output-filelist.txt"
if [[ -d "$input_basename" ]]; then
    find "$input_basename" -type f | sed 's/.*/"&"/' | sort >>"$workdir/$output-filelist.txt" # sort the files first, so they are packed in order
    find "$input_basename" -type d | sed 's/.*/"&"/' | sort >>"$workdir/$output-filelist.txt" # must add the directories as well to preserve the timestamps
elif [[ -f "$input_basename" ]]; then
    echo "$input_basename" >>"$workdir/$output-filelist.txt"
fi

read -p "Edit the $workdir/$output-filelist.txt for any exclusions, then press any key to continue (or Ctrl-C to abort)" -n1 -s

echo -e $UND"\n\nCreating RAR files using $threads CPU threads"$DEF
[[ -d "$input_basename" ]] && time rar a -r -hp$PASSWORD -mt${threads} -m0 -v${RAR_BLOCKSIZE}b -tsm -tsc -tsa "$workdir/$output/$FILENAME".rar @"$workdir/$output-filelist.txt"
[[ -f "$input_basename" ]] && time rar a -r -hp$PASSWORD -mt${threads} -m0 -v${RAR_BLOCKSIZE}b -tsm -tsc -tsa "$workdir/$output/$FILENAME".rar @"$workdir/$output-filelist.txt"

echo -e $UND"\nTesting RAR files"$DEF
first_par=$(ls "$workdir/$output/$FILENAME"*.rar | head -n 1)
if time rar -p$PASSWORD t -mt${threads} "$first_par" | grep "All OK"; then
    echo -e $UND"\nCreating PAR2 files with $PAR2_BINARY using $threads CPU threads"$DEF
    [[ $PAR2_BINARY == "par2" ]] && time $PAR2_BINARY c -t$threads -s${PAR2_BLOCKSIZE} -r${PAR2_REDUNDANCY} -l -v "$workdir/$output/$FILENAME" "$workdir/$output/$FILENAME".p*
    [[ $PAR2_BINARY == "parpar" ]] && time $PAR2_BINARY -t$threads -s${PAR2_BLOCKSIZE}b -r${PAR2_REDUNDANCY}% -o "$workdir/$output/$FILENAME" "$workdir/$output/$FILENAME".p*
    echo -e $BLD"
    Done, files are stored in: $workdir/$output
    Filename and password are stored in: $workdir/$output.txt
    "$DEF
else
    echo "RAR problem, aborting"
fi
