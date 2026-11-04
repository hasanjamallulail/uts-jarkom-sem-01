#!/usr/bin/env bash

cd "$HOME/Hasan" || exit 1

BASE="evidence/soal3"
CAP="$BASE/capture"
QOS="$BASE/qos"

{
    clear

    echo "================================================="
    echo " UTS CS238 - VERIFIKASI SELURUH HASIL SOAL 3"
    echo " TRANSPORT LAYER DAN QUALITY OF SERVICE"
    echo "================================================="

    echo ""
    echo "========== 1. STATUS CONTAINER =========="
    sudo docker ps --format \
      'table {{.Names}}\t{{.Status}}' | grep -E 'NAMES|clab-uts'

    echo ""
    echo "========== 2. STATUS INTERFACE =========="
    sudo docker exec clab-uts-PC-BR1 ip -4 addr show eth1
    sudo docker exec clab-uts-APP-SRV ip -4 addr show eth1

    echo ""
    echo "========== 3. STATUS ROUTING OSPF =========="
    for R in R-HQ R-BR1 R-BR2 R-DC; do
        echo ""
        echo "===== $R - NEIGHBOR ====="
        sudo docker exec "clab-uts-$R" \
          vtysh -c "show ip ospf neighbor"

        echo "===== $R - ROUTING ====="
        sudo docker exec "clab-uts-$R" \
          vtysh -c "show ip route ospf"
    done

    echo ""
    echo "========== 4. KONEKTIVITAS AKHIR =========="
    sudo docker exec clab-uts-PC-BR1 \
      ping -c 5 -W 1 10.10.30.10

    sudo docker exec clab-uts-PC-BR2 \
      ping -c 5 -W 1 10.10.30.10

    echo ""
    echo "========== 5. TCP HANDSHAKE =========="
    if [ -f "$CAP/tcp-handshake.txt" ]; then
        grep 'Flags' "$CAP/tcp-handshake.txt" | head -n 12
    else
        echo "Evidence handshake belum ditemukan"
    fi

    echo ""
    echo "========== 6. TCP SERVER MATI =========="
    if [ -f "$CAP/tcp-server-mati.txt" ]; then
        cat "$CAP/tcp-server-mati.txt"
    else
        echo "Evidence TCP server mati belum ditemukan"
    fi

    echo ""
    echo "========== 7. UDP SERVER MATI =========="
    if [ -f "$BASE/udp/udp-server-mati.txt" ]; then
        cat "$BASE/udp/udp-server-mati.txt"
    else
        echo "Evidence UDP server mati belum ditemukan"
    fi

    echo ""
    echo "========== 8. UDP TANPA RESPONS =========="
    if [ -f "$BASE/udp/udp-no-response-capture.txt" ]; then
        cat "$BASE/udp/udp-no-response-capture.txt"
    else
        echo "Evidence UDP tanpa respons belum ditemukan"
    fi

    if [ -f "$BASE/udp/udp-no-response-server.log" ]; then
        cat "$BASE/udp/udp-no-response-server.log"
    fi

    echo ""
    echo "========== 9. QOS BASELINE =========="
    if [ -f "$QOS/ping-baseline.txt" ]; then
        tail -n 4 "$QOS/ping-baseline.txt"
    fi

    echo ""
    echo "========== 10. QOS DELAY 100 MS =========="
    if [ -f "$QOS/ping-delay-100ms.txt" ]; then
        tail -n 4 "$QOS/ping-delay-100ms.txt"
    fi

    echo ""
    echo "========== 11. QOS PACKET LOSS 10% =========="
    if [ -f "$QOS/ping-loss-10pct.txt" ]; then
        tail -n 4 "$QOS/ping-loss-10pct.txt"
    fi

    echo ""
    echo "========== 12. WAKTU RESPONS TCP =========="
    if [ -f "$QOS/tcp-response.txt" ]; then
        cat "$QOS/tcp-response.txt"
    fi

    echo ""
    echo "========== 13. TRANSFER FILE TCP =========="
    if [ -f "$QOS/tcp-transfer-fixed.csv" ]; then
        cat "$QOS/tcp-transfer-fixed.csv"
    fi

    echo ""
    echo "========== 14. UDP BASELINE =========="
    if [ -f "$QOS/udp-fixed-BASELINE.txt" ]; then
        cat "$QOS/udp-fixed-BASELINE.txt"
    fi

    echo ""
    echo "========== 15. UDP PACKET LOSS =========="
    if [ -f "$QOS/udp-fixed-LOSS_10PCT.txt" ]; then
        cat "$QOS/udp-fixed-LOSS_10PCT.txt"
    fi

    echo ""
    echo "========== 16. TCP RETRANSMISSION =========="
    for FILE in \
        tcp-retransmission-analysis.txt \
        tcp-duplicate-ack.txt \
        tcp-lost-segment.txt
    do
        if [ -f "$CAP/$FILE" ]; then
            echo "$FILE : $(wc -l < "$CAP/$FILE") baris"
        else
            echo "$FILE : BELUM ADA"
        fi
    done

    echo ""
    echo "========== 17. KONDISI QDISC AKHIR =========="
    PID=$(sudo docker inspect -f '{{.State.Pid}}' \
      clab-uts-PC-BR1)

    sudo nsenter -t "$PID" -n \
      tc qdisc show dev eth1

    echo ""
    echo "========== 18. DAFTAR SELURUH EVIDENCE =========="
    find "$BASE" -type f | sort

    echo ""
    echo "========== 19. TOTAL FILE EVIDENCE =========="
    find "$BASE" -type f | wc -l

    echo ""
    echo "================================================="
    echo " VERIFIKASI FINAL SOAL 3 SELESAI"
    echo "================================================="

} 2>&1 | tee "$BASE/hasil-verifikasi-final.txt"
