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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
nvm use lts/gallium

usage=$blu"
Usage: $(basename "$0") -i <input dir> -o <output dir> -p <pack dir (optional)> -t <threads (optional)>
Escape special characters in names if necessary, e.g. brackets: \[testdirectory\]
Use double quotes if the directory has spaces, e.g. \"This is a test directory\"
  -h              - This help.

  Mandatory parameters:
  -i <input dir>  - Input directory or file to pack. Can be a pathname.
  -o <output dir> - Output directory where the packed files will be written.
                    Do NOT use a pathname here, just a dirname.
  
  Optional parameters:
  -d <disc>       - For packing multiple discs separately, pass each disc's folder with -d
                    e.g. -d 'disc 1' -d 'disc 2' -d 'disc 3'
  -p <pack dir>   - Packing directory where the project (packed files, txt, nzbs) will be stored
                    (default '<current dir>/packing').
  -t <threads>    - CPU threads (default = maximum threads).
"$DEF

while getopts ":hi:o:d:p:t:" opt; do
    case "$opt" in
    h)
        echo -e "$usage"
        exit
        ;;
    i) input="$OPTARG" ;;
    o) output="$OPTARG" ;;
    d) discsArray+=("$OPTARG") ;; # multiple arguments to option, put the values in array https://stackoverflow.com/a/20761965
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

if [[ "$output" == */* ]]; then
    echo -e $red"Output parameter '$output' should NOT be a pathname"$DEF
    exit 1
fi

# optional arguments
if ((${#discsArray[@]} == 0)); then #if array length = 0, i.e. not set
    discsArray[0]="*"               # default
fi

if [[ -z $packdir ]]; then
    workdir="$(pwd)/packing"
else
    workdir=$(realpath "$packdir") # realpath removes any trailing slashes
fi

if [[ -z "$threads" ]]; then
    threads=$(nproc)
fi

if (($LENGTH_FILE < 6)) || (($LENGTH_PASSWORD < 6)); then
    echo "Random length for filename or password should be > 6, change it in the config.env file."
    exit 1
fi

# generate random chars for filename and password
FILENAME="$FILENAME_PREFIX"$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $LENGTH_FILE | head -n 1)
PASSWORD="$PASSWORD_PREFIX"$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $LENGTH_PASSWORD | head -n 1)

input_basename=$(basename "$input")
input_dirname=$(dirname "$input")
output_basename=$(basename "$output")

# do the work from the parent dir of the input file/dir
cd "$input_dirname"

rm -rf "$workdir"
mkdir -p "$workdir"
echo -e "Packing (working) dir: $workdir\n"

# loop the array
count=1
for folder in "${discsArray[@]}"; do
    disc="d$count"

    # check size of array
    len=${#discsArray[@]}
    if ((len > 1)); then
        output="$output-$disc"
        FILENAME="$FILENAME-$disc"
        input_basename="$input_basename/$folder"
    fi

    # write the filename/password to a file, so we don't lose it!
    echo Filename: $FILENAME >"$workdir/$output.txt"
    echo Password: $PASSWORD >>"$workdir/$output.txt"
    echo Input file/dir: "$input_basename" >>"$workdir/$output.txt"
    echo Output dir: "$output" >>"$workdir/$output.txt"
    cat "$workdir/$output.txt"

    rm -f "$workdir/$output-filelist.txt" # cleanup any previous file list
    if [[ -d "$input_basename" ]]; then
        find "$input_basename" -type f | sed 's/.*/"&"/' | sort >>"$workdir/$output-filelist.txt" # sort the files first, so they are packed in order
        find "$input_basename" -type d | sed 's/.*/"&"/' | sort >>"$workdir/$output-filelist.txt" # must add the directories as well to preserve the timestamps
    elif [[ -f "$input_basename" ]]; then
        echo "$input_basename" >>"$workdir/$output-filelist.txt"
    fi

    read -p "Edit the $workdir/$output-filelist.txt for any exclusions, then press any key to continue (or Ctrl-C to abort)" -n1 -s

    echo -e $UND"\n\nCreating RAR files using $threads CPU threads"$DEF

    mkdir -p "$workdir/$output"
    time rar a -r -hp$PASSWORD -mt${threads} -m0 -v${RAR_BLOCKSIZE}b -tsm -tsc -tsa \
        "$workdir/$output/$FILENAME".rar @"$workdir/$output-filelist.txt"

    echo -e $UND"\nTesting RAR files"$DEF

    first_par=$(ls "$workdir/$output/$FILENAME"*.rar | head -n 1)
    if time rar -p$PASSWORD t -mt${threads} "$first_par" | grep "All OK"; then
        echo -e $UND"\nCreating PAR2 files with $PAR2_BINARY using $threads CPU threads"$DEF

        if [[ $PAR2_BINARY == "par2" ]]; then
            time $PAR2_BINARY c -t$threads -s${PAR2_BLOCKSIZE} -r${PAR2_REDUNDANCY} -l -v \
                "$workdir/$output/$FILENAME" "$workdir/$output/$FILENAME".p*
        fi
        if [[ $PAR2_BINARY == "parpar" ]]; then
            SLICES_PER_FILE=$(($RAR_BLOCKSIZE / $PAR2_BLOCKSIZE))
            echo "SLICES_PER_FILE=$SLICES_PER_FILE"
            time $PAR2_BINARY -t$threads -s${PAR2_BLOCKSIZE}b -r${PAR2_REDUNDANCY}% -p $SLICES_PER_FILE -o \
                "$workdir/$output/$FILENAME" "$workdir/$output/$FILENAME".p*
        fi
        echo -e $BLD"
    Files (rar and par2) are stored in: $workdir/$output
    Randomized filename and password are stored in: $workdir/$output.txt
    "$DEF

    else
        echo "RAR problem, aborting"
    fi

    # remove the appended -$disc with bash native replacement
    output=${output/-$disc/}
    FILENAME=${FILENAME/-$disc/}
    input_basename=${input_basename/"/$folder"/}

    count=$((count + 1))
done
