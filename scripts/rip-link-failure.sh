#!/bin/bash

set -u

R="clab-uts-R-BR1"
PC1="clab-uts-PC-BR1"
PC2="clab-uts-PC-BR2"
DST="10.10.30.10"

restore() {
    echo "===== MEMASTIKAN LINK BR1 AKTIF ====="
    sudo docker exec "$R" ip link set eth1 up
}

trap restore EXIT INT TERM

echo "=========================================="
echo " UTS CS238 - RIP VERSION 2 LINK FAILURE"
echo "=========================================="
date -Is

echo
echo "===== 1. BASELINE SEBELUM GANGGUAN ====="
sudo docker exec "$R" ip link show eth1
sudo docker exec "$R" vtysh -c "show ip route rip"
sudo docker exec "$PC1" ping -c 3 -W 1 "$DST"

echo
echo "===== 2. PUTUS LINK R-BR1 KE R-HQ ====="
date -Is
sudo docker exec "$R" ip link set eth1 down
sudo docker exec "$R" ip link show eth1

echo
echo "===== 3. TABEL RIP SAAT LINK DOWN ====="
sudo docker exec "$R" vtysh -c "show ip route rip"

echo
echo "===== 4. PING BR1 SAAT LINK DOWN ====="
sudo docker exec "$PC1" ping -c 5 -W 1 "$DST" || true

echo
echo "===== 5. PING BR2 SAAT BR1 DOWN ====="
sudo docker exec "$PC2" ping -c 5 -W 1 "$DST" || true

echo
echo "===== 6. PEMERIKSAAN RIP SETELAH GANGGUAN ====="
sudo docker exec "$R" vtysh -c "show ip route rip"

echo
echo "===== 7. PEMULIHAN LINK ====="
date -Is
restore
sleep 5

echo
echo "===== 8. TABEL RIP SETELAH PEMULIHAN ====="
sudo docker exec "$R" vtysh -c "show ip route rip"

echo
echo "===== 9. PING SETELAH PEMULIHAN ====="
sudo docker exec "$PC1" ping -c 5 -W 1 "$DST" || true

echo
echo "===== EKSPERIMEN SELESAI ====="
date -Is

trap - EXIT INT TERM
