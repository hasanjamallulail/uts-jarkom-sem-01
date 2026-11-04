#!/bin/bash

set -u

restore_link() {
    echo ""
    echo "===== PEMULIHAN INTERFACE BR1 ====="
    sudo docker exec clab-uts-R-BR1 ip link set eth1 up
}

trap restore_link EXIT

echo "=========================================="
echo " UTS CS238 - SIMULASI LINK FAILURE"
echo " Link: R-BR1 menuju R-HQ"
echo "=========================================="
date -Is

echo ""
echo "===== BASELINE SEBELUM GANGGUAN ====="
sudo docker exec clab-uts-R-BR1 ip link show eth1
sudo docker exec clab-uts-PC-BR1 ping -c 3 -W 1 10.10.30.10

echo ""
echo "===== PUTUSKAN LINK ====="
sudo docker exec clab-uts-R-BR1 ip link set eth1 down

echo ""
echo "===== STATUS LINK DOWN ====="
sudo docker exec clab-uts-R-BR1 ip link show eth1

echo ""
echo "===== TABEL ROUTING SAAT LINK DOWN ====="
sudo docker exec clab-uts-R-BR1 vtysh -c "show ip route"

echo ""
echo "===== PING BR1 KE SERVER SAAT DOWN ====="
sudo docker exec clab-uts-PC-BR1 ping -c 5 -W 1 10.10.30.10 || true

echo ""
echo "===== PING BR2 KE SERVER SAAT BR1 DOWN ====="
sudo docker exec clab-uts-PC-BR2 ping -c 5 -W 1 10.10.30.10 || true

echo ""
echo "===== PEMULIHAN ====="
restore_link

echo ""
echo "===== STATUS LINK SETELAH UP ====="
sudo docker exec clab-uts-R-BR1 ip link show eth1

echo ""
echo "===== PING SETELAH PEMULIHAN ====="
sudo docker exec clab-uts-PC-BR1 ping -c 5 -W 1 10.10.30.10 || true

trap - EXIT
echo ""
echo "===== EKSPERIMEN SELESAI ====="
date -Is
