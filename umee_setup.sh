#!/bin/bash


exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi

function setup_Vars {
	if [ ! $UMEE_NODENAME ]; then
		read -p "Enter node name: " UMEE_NODENAME
		echo 'export UMEE_NODENAME='\"${UMEE_NODENAME}\" >> $HOME/.bash_profile
	fi
	. $HOME/.bash_profile
	sleep 1
}


function install_Go {
	cd $HOME
	wget -O go1.18.5.linux-amd64.tar.gz https://golang.org/dl/go1.18.5.linux-amd64.tar.gz
	rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.5.linux-amd64.tar.gz && rm go1.18.5.linux-amd64.tar.gz
	echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
	echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
	echo 'export GO111MODULE=on' >> $HOME/.bash_profile
	echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
	go version
}

function install_Deps {
	cd $HOME
	sudo apt update
	sudo apt install make clang pkg-config libssl-dev build-essential git jq ncdu bsdmainutils htop net-tools lsof -y < "/dev/null"
}


function install_Software {
	cd $HOME
	git clone https://github.com/umee-network/umee.git
	cd umee
	git pull
	git checkout v3.1.0
	make build
	sudo cp $HOME/umee/build/umeed /usr/local/bin
	umeed version
	umeed init $UMEE_NODENAME --chain-id umee-1
	wget -O $HOME/.umee/config/genesis.json https://github.com/umee-network/mainnet/raw/main/genesis.json
	sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0uumee\"/" $HOME/.umee/config/app.toml
}



function state_sync {
	sudo systemctl stop umeed
	mv $HOME/.umee/data/priv_validator_state.json $HOME/.umee
	umeed tendermint unsafe-reset-all
	mv $HOME/.umee/priv_validator_state.json $HOME/.umee/data/
	
	peers="2185f05f4e39f9de8590cb17aac54bca2e14357f@89.163.164.207:26656"
	sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.umee/config/config.toml

	SNAP="http://89.163.164.207:26657"
	LATEST_HEIGHT=$(curl -s $SNAP/block | jq -r .result.block.header.height)
	TRUST_HEIGHT=$((LATEST_HEIGHT - 1000))
	TRUST_HASH=$(curl -s "$SNAP/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)

	sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
	s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP,$SNAP\"| ; \
	s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$TRUST_HEIGHT| ; \
	s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.umee/config/config.toml
	sed -i -e "s/^snapshot-interval *=.*/snapshot-interval = 2000/" $HOME/.umee/config/app.toml

	sudo systemctl start umeed
	journalctl -u umeed -f
}


function install_Service {

echo "[Unit]
Description=Umee Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which umeed) start
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/umeed.service
sudo mv $HOME/umeed.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable umeed
}




PS3='Please enter your choice (input your option number and press enter): '
options=("full installation on a new server" "state_sync" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "full installation on a new server")
            		sleep 1
			setup_Vars
			install_Go
			install_Deps
			install_Software
			install_Service
			state_sync
			break
            ;;
        "state_sync")
            		sleep 1
			state_sync
			break
            ;;
        "Quit")
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done
