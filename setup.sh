if [ -z "$DEV_PASSWORD" ]; then
  echo "Error: DEV_PASSWORD is not set. Aborting."
  exit 1
fi

# -- Create dev user --
useradd -m -g sudo dev
echo "dev:$DEV_PASSWORD" | chpasswd
mkdir -p /home/dev/.ssh
cp /home/user/.ssh/authorized_keys /home/dev/.ssh/authorized_keys

chown -R dev:dev /home/dev/.ssh
chmod 700 /home/dev/.ssh
chmod 600 /home/dev/.ssh/authorized_keys

sudo groupadd docker || true
sudo usermod -aG docker dev

# -- Change to dev user --
su - dev <<'EOF'

# Exit if error
set -e

# -- Install zsh --
echo "$DEV_PASSWORD" | sudo -S apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
sudo apt install zsh git vim -y
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="af-magic"/' ~/.zshrc
sed -i '/^plugins=(/ s/)/ zsh-autosuggestions)/' ~/.zshrc
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

sudo chsh -s $(which zsh)

echo "export 'DEBIAN_FRONTEND=noninteractive'" >> ~/.zshrc
source ~/.zshrc

# -- Install docker --

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

newgrp docker

# -- Run Isaac Sim compatibility checker --
docker pull nvcr.io/nvidia/isaac-sim-comp-check:4.5.0
docker run --name isaac-sim-comp-check --runtime=nvidia --gpus all -e "ACCEPT_EULA=Y" --rm --network=host -e "PRIVACY_CONSENT=Y" nvcr.io/nvidia/isaac-sim-comp-check:4.5.0

# -- Install WireGuard --
sudo apt install -y wireguard

# Generate WireGuard Server Keys
umask 077 
mkdir -p ~/.wireguard
chmod 700 ~/.wireguard
wg genkey | tee ~/.wireguard/server_private.key | wg pubkey > ~/.wireguard/server_public.key 

# Create WireGuard Configuration
echo "
[Interface]
# Virtual IP for the VPN server within the VPN subnet
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(cat ~/.wireguard/server_private.key)
# Enable NAT to allow VPN clients to reach the VPC
PostUp   = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# (Client peer configuration will be added here later)
" | sudo tee /etc/wireguard/wg0.conf

sudo sysctl -w net.ipv4.ip_forward=1 

# Start WireGuard service
sudo systemctl start wg-quick@wg0 
sudo systemctl enable wg-quick@wg0

# -- Install Isaac sim --
docker pull nvcr.io/nvidia/isaac-sim:4.5.0

# Run Isaac Sim Container
# docker run --name isaac-sim --entrypoint bash -it --runtime=nvidia --gpus all -e "ACCEPT_EULA=Y" --rm --network=host \
#     -e "PRIVACY_CONSENT=Y" \
#     -v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
#     -v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
#     -v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
#     -v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
#     -v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
#     -v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
#     -v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
#     -v ~/docker/isaac-sim/documents:/root/Documents:rw \
#     nvcr.io/nvidia/isaac-sim:4.5.0
  

EOF
