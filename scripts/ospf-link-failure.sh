#!/bin/bash

set -u

R="clab-uts-R-BR1"
PC1="clab-uts-PC-BR1"
PC2="clab-uts-PC-BR2"
DST="10.10.30.10"

restore() {
    echo "===== MEMULIHKAN LINK BR1-HQ ====="
    sudo docker exec "$R" ip link set eth1 up
}

trap restore EXIT

echo "=========================================="
echo " UTS CS238 - OSPF LINK FAILURE"
echo "=========================================="
date -Is

echo ""
echo "===== 1. BASELINE SEBELUM GANGGUAN ====="
sudo docker exec "$R" ip link show eth1
sudo docker exec "$R" vtysh -c "show ip route ospf"
sudo docker exec "$PC1" ping -c 3 -W 1 "$DST"

echo ""
echo "===== 2. PUTUS LINK BR1-HQ ====="
date -Is
sudo docker exec "$R" ip link set eth1 down
sudo docker exec "$R" ip link show eth1

echo ""
echo "===== 3. ROUTING OSPF SAAT LINK DOWN ====="
sudo docker exec "$R" vtysh -c "show ip route ospf"

echo ""
echo "===== 4. PING BR1 SAAT LINK DOWN ====="
sudo docker exec "$PC1" ping -c 5 -W 1 "$DST" || true

echo ""
echo "===== 5. PING BR2 SAAT BR1 DOWN ====="
sudo docker exec "$PC2" ping -c 5 -W 1 "$DST" || true

echo ""
echo "===== 6. PEMULIHAN LINK ====="
date -Is
restore

echo ""
echo "===== 7. STATUS OSPF SETELAH LINK UP ====="
sudo docker exec "$R" vtysh -c "show ip ospf neighbor"
sudo docker exec "$R" vtysh -c "show ip route ospf"

echo ""
echo "===== 8. PING SETELAH PEMULIHAN ====="
sudo docker exec "$PC1" ping -c 5 -W 1 "$DST" || true

echo ""
echo "===== EKSPERIMEN SELESAI ====="
date -Is
