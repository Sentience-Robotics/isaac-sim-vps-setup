OFFER_ID="<YOUR_OFFER_ID>"
vastai create instance $OFFER_ID --image docker.io/vastai/kvm:ubuntu_cli_22.04-2025-03-04 --env '-p 741641:741641/udp -p 51820:51820/udp -e DEV_PASSWORD=lucy -e WIREGUARD_CLIENT_PUBLIC_KEY=exzNypxvdjM+gfLmw/osBJr3zMBkF1ei63xaDzYVU2M= -e WIREGUARD_CLIENT_IP=10.0.0.2' --disk 60 --ssh --direct
