# Usenet packing and posting scripts
The scripts were written for `bash` and tested on Ubuntu 22.04. The package managment was also added for Alpine and RHEL linux distros. If running on Alpine, make sure you switch to `bash` before running any of the scripts.

## Features
- Randomize the filenames and passwords for the rar files.
- Randomize the uploader's name and email (optional).
- Support packing and posting of multiple folders/subfolders.
- Support embedding the rar password into the nzbs.
- Can choose `par2cmdline` or `parpar` for par2 creation. `parpar` is recommended for its efficiency and speed.
- Multi linux distros support (tested on Ubuntu 22.04 and Centos 7).

## Installation
Clone this repository and run the installer. `sudo` access may be needed, unless the required binaries (`automake` `git` `zip` `wget`) are already installed on the system. Dependencies and several tools will be downloaded, installed and/or compiled, then the cloned dir will be added to the PATH. Relogin for changes to take effect.
```
git clone https://github.com/buggsi/usenet-scripts
cd usenet-scripts
chmod +x *.sh
./install.sh
```

A `config` folder will be created with a `config.env` file and a `nyuu-provider.json`.\
Edit both files before proceeding.\
Rename `nyuu-provider.json` by replacing the "provider" string with your usenet provider name.\
If you have multiple providers, copy/paste and edit the `nyuu-provider.json` template accordingly.\
For security, make sure the json files have `chmod 600` permissions.
For example:
```
nyuu-blocknews.json
nyuu-newshosting.json
nyuu-usenetnow.json
```

The `pack.sh` and `post.sh` scripts are self-explanatory. For help, run them by themselves or with `-h`. I recommend to run both scripts in a `screen` or `tmux` session, to avoid interruptions especially if processing big folders, e.g. `screen -S packing_session`

```
Usage: pack.sh -i <input dir> -o <output dir> -p <pack dir (optional)> -t <threads (optional)>
Escape special characters in names if necessary, e.g. brackets: \[testdirectory\]
Use double quotes if the directory has spaces, e.g. "This is a test directory"
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
```

```
Usage: post.sh -p <usenet provider> -i <input dir to upload>
Escape special characters in names if necessary, e.g. brackets: \[testdirectory\]
Use double quotes if the directory has spaces, e.g. "This is a test directory"
  -h                 - This help.
  
  Mandatory parameters:
  -p <provider>      - Usenet provider name, e.g. blocknews, eweka, newshosting.
  -i <input dir>     - Directory to upload containing the rar/par2 files.
                       Can be a relative or full pathname, and can be passed multiple times.
                       e.g. -i disc1 -i disc2 -i disc3 -i /path/to/disc4
```

`pack.sh` will `rar` a folder or single file, then create `par2` files.\
`post.sh` will post to usenet using `nyuu` (https://github.com/animetosho/Nyuu). It's fast and well maintained.

# Usage examples
For the provider blocknews, create the json file `config/nyuu-blocknews.json` and edit it.

- Pack a folder, can use relative or full pathnames for the input folder. The output folder (`-o` switch) should NOT be a pathname. If you want the packed output folder to be stored in a different location, use the `-p` switch. The double quotes are only needed if dirnames have spaces.\
`pack.sh -i "Test folder to pack" -o "Release folder"`\
`pack.sh -i "/home/user/Test folder to pack" -o "Release folder"`\
`pack.sh -i "/home/user/Test folder to pack" -o "Release folder" -p "/home/user/tmp/New workdir"`\

- Upload to usenet, can use relative or full pathnames.\
`post.sh -p blocknews -i "Release folder" -e true`\
`post.sh -p blocknews -i "/home/user/packing/Release folder" -e true`\
`post.sh -p blocknews -i "/home/user/packing/Release folder-disc1" -i "/home/user/packing/Release folder-disc2" -e true`\
`post.sh` will create a first nzb file for the rars/par2 files, and a second nzb of the first nzb, which will be posted as file 0 in the subject.\
e.g `subject="Release folder - &quot;6SEWEmEw2dq5vexdDQxV.nzb&quot; [0/9] (1/1)"`
