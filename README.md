# Umee Mainnet state sync

#### Automatic installation

```
wget https://raw.githubusercontent.com/studentmtk/Umee-Mainnet-state-sync/main/umee_setup.sh
bash umee_setup.sh
```
select  
1 - complete installation of the environment on a new server and fast synchronization  
2 - the server already has the umeed binary file, the network is initialized and you want to quickly catch up with the height of the network  
3 - exit the menu

#### Manual installation


##### Installing the necessary environment

```
sudo apt install curl -y < "/dev/null"
```
```
cd $HOME
sudo apt update
sudo apt install make clang pkg-config libssl-dev build-essential git jq ncdu bsdmainutils htop net-tools lsof -y < "/dev/null"
```

#### installing Go
```
cd $HOME
wget -O go1.18.5.linux-amd64.tar.gz https://golang.org/dl/go1.18.5.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.5.linux-amd64.tar.gz && rm go1.18.5.linux-amd64.tar.gz
echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
echo 'export GO111MODULE=on' >> $HOME/.bash_profile
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
go version
```

#### Creating a binary umeed file
```
cd $HOME
git clone https://github.com/umee-network/umee.git
cd umee
git pull
git checkout v3.0.2
make build
sudo cp $HOME/umee/build/umeed /usr/local/bin
umeed version

```

#### Initializing the necessary files

```
umeed init $UMEE_NODENAME --chain-id umee-1
wget -O $HOME/.umee/config/genesis.json https://github.com/umee-network/mainnet/raw/main/genesis.json
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0uumee\"/" $HOME/.umee/config/app.toml
```

#### Creating a service file
```  
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
```

#### Preparing for fast synchronization

```
systemctl stop umeed
cp $HOME/.umee/data/priv_validator_state.json $HOME/.umee
umeed tendermint unsafe-reset-all --keep-addr-book
mv $HOME/.umee/priv_validator_state.json $HOME/.umee/data/

peers="2185f05f4e39f9de8590cb17aac54bca2e14357f@89.163.164.207:26656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.umee/config/config.toml
```
```
SNAP="http://89.163.164.207:26657"
LATEST_HEIGHT=$(curl -s $SNAP/block | jq -r .result.block.header.height)
TRUST_HEIGHT=$((LATEST_HEIGHT - 1000))
TRUST_HASH=$(curl -s "$SNAP/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)
```
```
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP,$SNAP\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$TRUST_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.umee/config/config.toml
```
```
sed -i -e "s/^snapshot-interval *=.*/snapshot-interval = 2000/" $HOME/.umee/config/app.toml
sudo systemctl start umeed
journalctl -u umeed -f
```  
  
After you catch up with the height of the network, " stop systemctl stop umeed ", replace the file " $HOME/.umee/config/priv_validator_key.json " to your validator file and run " systemctl start umeed " again.
  
  
  
  
  
  


