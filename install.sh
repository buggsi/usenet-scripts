#!/usr/bin/env bash

# exit when any command fails
set -e

PATH=$(pwd)/bin:$PATH
appdir="$(pwd)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
command -v nvm &>/dev/null && nvm use lts/gallium

function checkCommands {
    arr=("$@")
    bold=$(tput bold)
    normal=$(tput sgr0)
    echo $bold"Checking commands"$normal
    for i in "${arr[@]}"; do
        if command -v $i &>/dev/null; then
            command -v $i | grep $i | sed 's/$/ OK ✓/'
        else
            echo $bold"$i missing or not installed properly"$normal
            return 1 # 1 = false
        fi
    done
    return 0 # 0 = true
}

mkdir -p bin/temp config
cd bin

array=(automake git zip wget)
if ! checkCommands "${array[@]}"; then
    echo "Missing one of these linux dependencies: ${array[@]}"
    echo "Installing now (sudo permissions required)..."
    command -v apt &>/dev/null && sudo apt install -y automake git zip wget # debian, ubuntu
    command -v dnf &>/dev/null && sudo dnf install -y automake git zip wget # rhel, fedora, centos
    command -v apk &>/dev/null && sudo apk add automake git zip wget        # alpine
    sleep 2
fi

if ! command -v "$appdir/bin/color" &>/dev/null; then
    git clone https://github.com/vaniacer/bash_color temp/bash_color
    mv temp/bash_color/color .
fi

if ! command -v "$appdir/bin/rar" &>/dev/null; then
    wget -nc --no-check-certificate https://www.rarlab.com/rar/rarlinux-x64-5.5.0.tar.gz
    tar xzvf rarlinux-x64-5.5.0.tar.gz -C temp
    mv temp/rar/rar temp/rar/unrar .
    sleep 2
fi

if ! command -v "$appdir/bin/par2" &>/dev/null; then
    echo "Missing par2, installing..."
    git clone https://github.com/animetosho/par2cmdline-turbo temp/par2cmdline
    cd temp/par2cmdline
    ./automake.sh
    ./configure
    make
    make check
    #make install
    mv par2 ../../
    sleep 2
fi

if ! command -v nvm &>/dev/null; then
    echo "Missing nvm, installing..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

    nvm install lts/gallium
    npm install -g npm@latest
    sleep 2
else
    nvm install lts/gallium
    npm install -g npm@latest
    nvm use lts/gallium
fi

if ! command -v nyuu &>/dev/null; then
    # https://github.com/animetosho/Nyuu
    echo "Missing nyuu, installing..."
    npm install -g nyuu --production
    sleep 2
fi

if ! command -v parpar &>/dev/null; then
    npm install -g @animetosho/parpar
    sleep 2
fi

if ! command -v "$appdir/bin/json" &>/dev/null; then
    # https://stackoverflow.com/a/62835220/5369345
    curl -L https://github.com/trentm/json/raw/master/lib/json.js >"$appdir/bin/json"
    chmod +x "$appdir/bin/json"
    echo '{"hello":{"hi":"there"}}' | json "hello.hi"
    sleep 2
fi

cd "$appdir"
rm -rf bin/temp

array=(nvm nyuu parpar color json par2 rar)
checkCommands "${array[@]}" || exit 1

if [[ -f ~/.profile ]]; then
    rcfile=".profile"
elif [[ -f ~/.bashrc ]]; then
    rcfile=".bashrc"
fi
if ! grep -q "$appdir" ~/$rcfile; then
    echo -e "\nAdding $appdir to PATH in ~/$rcfile"
    echo export \"PATH=\$PATH:$appdir\" >>~/$rcfile
fi

cp -np example-config.env config/config.env
cp -np example-nyuu-provider.json config/nyuu-provider.json
chmod 600 config/nyuu-provider.json

echo -e "\nIf this is the first time you run install.sh,\nlogoff and relogin for the nvm and path environment to take effect.\n"
