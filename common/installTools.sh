
if [ ! -f /usr/local/bin/govc ]; then
    echo "Installing govc"
    wget -q https://github.com/vmware/govmomi/releases/download/v0.48.1/govc_Linux_x86_64.tar.gz
    tar -xf govc_Linux_x86_64.tar.gz
    sudo install govc /usr/local/bin/govc
    rm -f govc_Linux_x86_64.tar.gz
    rm -f govc
    rm -f CHANGELOG.md
    rm -f LICENSE.txt
    rm -f README.md
fi

if [ ! -f /usr/local/bin/ytt ]; then
    echo "Installing ytt"
    wget -q https://github.com/vmware-tanzu/carvel-ytt/releases/download/v0.51.1/ytt-linux-amd64
    sudo install ytt-linux-amd64 /usr/local/bin/ytt 
    rm -f ytt-linux-amd64
fi
