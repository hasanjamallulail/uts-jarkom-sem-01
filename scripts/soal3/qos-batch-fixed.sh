#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan" || exit 1

OUT="evidence/soal3/qos"
CAP="evidence/soal3/capture"
CLIENT="clab-uts-PC-BR1"
SERVER="clab-uts-APP-SRV"

mkdir -p "$OUT" "$CAP"

CPID=$(sudo docker inspect -f '{{.State.Pid}}' "$CLIENT") || exit 1
SPID=$(sudo docker inspect -f '{{.State.Pid}}' "$SERVER") || exit 1

cleanup() {
    sudo nsenter -t "$CPID" -n \
      tc qdisc del dev eth1 root 2>/dev/null || true
}

CURRENT=$(sudo nsenter -t "$CPID" -n tc qdisc show dev eth1)

if ! grep -q 'qdisc noqueue' <<< "$CURRENT"; then
    echo "ERROR: qdisc awal bukan noqueue. Eksperimen dibatalkan."
    echo "$CURRENT"
    exit 1
fi

trap cleanup EXIT

echo "========================================"
echo " UTS CS238 - QOS BATCH PERBAIKAN"
echo "========================================"

echo ""
echo "===== PERSIAPAN FILE TCP 256 KIB ====="

sudo docker exec "$CLIENT" sh -c \
  'dd if=/dev/urandom of=/tmp/qos-test.bin bs=1024 count=256 2>/dev/null'

EXPECTED_SIZE=$(sudo docker exec "$CLIENT" \
  sh -c 'wc -c < /tmp/qos-test.bin')

EXPECTED_HASH=$(sudo docker exec "$CLIENT" \
  sha256sum /tmp/qos-test.bin | awk '{print $1}')

echo "Ukuran sumber: $EXPECTED_SIZE byte"
echo "SHA256 sumber: $EXPECTED_HASH"

echo "kondisi,waktu_ms,byte_diterima,exit_code,integritas" \
  > "$OUT/tcp-transfer-fixed.csv"

tcp_test() {
    LABEL="$1"

    echo ""
    echo "===== TCP TRANSFER: $LABEL ====="

    sudo docker exec "$SERVER" \
      sh -c 'killall nc 2>/dev/null || true'

    sudo docker exec "$SERVER" \
      sh -c ': > /tmp/qos-received.bin'

    sudo docker exec -d "$SERVER" \
      sh -c 'nc -l -p 5002 > /tmp/qos-received.bin'

    sleep 1

    if ! sudo nsenter -t "$SPID" -n \
      ss -lnt | grep -q ':5002'; then
        echo "ERROR: TCP server belum LISTEN"
        echo "$LABEL,0,0,1,SERVER_GAGAL" \
          >> "$OUT/tcp-transfer-fixed.csv"
        return
    fi

    CAP_PID=""

    if [ "$LABEL" = "LOSS_10PCT" ]; then
        sudo timeout 20 \
          nsenter -t "$SPID" -n \
          tcpdump -i eth1 -nn -U \
          -w "$CAP/tcp-transfer-loss-fixed.pcap" \
          'host 10.10.20.10 and tcp port 5002' \
          2> "$CAP/tcp-transfer-loss-fixed-info.txt" &

        CAP_PID=$!
        sleep 1
    fi

    START=$(date +%s%N)

    sudo timeout 30 docker exec "$CLIENT" \
      sh -c 'nc -w 20 10.10.30.10 5002 < /tmp/qos-test.bin'

    NC_EXIT=$?
    END=$(date +%s%N)

    sleep 1

    MS=$(( (END - START) / 1000000 ))

    BYTES=$(sudo docker exec "$SERVER" \
      sh -c 'wc -c < /tmp/qos-received.bin' \
      2>/dev/null || echo "ERROR")

    RECEIVED_HASH=$(sudo docker exec "$SERVER" \
      sha256sum /tmp/qos-received.bin 2>/dev/null \
      | awk '{print $1}')

    if [ "$NC_EXIT" -eq 0 ] &&
       [ "$BYTES" = "$EXPECTED_SIZE" ] &&
       [ "$RECEIVED_HASH" = "$EXPECTED_HASH" ]; then
        INTEGRITY="VALID"
    else
        INTEGRITY="TIDAK_VALID"
    fi

    echo "Waktu transfer: ${MS} ms"
    echo "Ukuran diterima: $BYTES byte"
    echo "Exit code client: $NC_EXIT"
    echo "SHA256 penerima: $RECEIVED_HASH"
    echo "Integritas: $INTEGRITY"

    echo "$LABEL,$MS,$BYTES,$NC_EXIT,$INTEGRITY" \
      >> "$OUT/tcp-transfer-fixed.csv"

    if [ -n "$CAP_PID" ]; then
        wait "$CAP_PID" || true

        sudo tcpdump -nn \
          -r "$CAP/tcp-transfer-loss-fixed.pcap" \
          > "$CAP/tcp-transfer-loss-fixed.txt" 2>&1

        echo "Packet capture TCP tersimpan."
    fi
}

udp_test() {
    LABEL="$1"
    LOG="$OUT/udp-fixed-$LABEL.txt"

    echo ""
    echo "===== UDP: $LABEL ====="

    sudo nsenter -t "$SPID" -n \
      python3 -u scripts/soal3/udp_qos_fixed.py \
      server "$LABEL" --count 100 \
      > "$LOG" 2>&1 &

    UDP_PID=$!

    READY=0

    for i in $(seq 1 20); do
        if grep -q "UDP_SERVER_READY" "$LOG"; then
            READY=1
            break
        fi
        sleep 0.2
    done

    if [ "$READY" -ne 1 ]; then
        echo "ERROR: UDP server gagal aktif"
        cat "$LOG"
        wait "$UDP_PID" || true
        return
    fi

    sudo nsenter -t "$CPID" -n \
      python3 scripts/soal3/udp_qos_fixed.py \
      client "$LABEL" --count 100

    wait "$UDP_PID"
    UDP_EXIT=$?

    cat "$LOG"
    echo "Exit code server UDP: $UDP_EXIT"
}

{
    echo ""
    echo "========== BASELINE =========="

    tcp_test "BASELINE"
    udp_test "BASELINE"

    echo ""
    echo "========== DELAY 100 MS =========="

    sudo nsenter -t "$CPID" -n \
      tc qdisc replace dev eth1 root netem delay 100ms

    sudo nsenter -t "$CPID" -n \
      tc qdisc show dev eth1

    tcp_test "DELAY_100MS"

    cleanup

    echo ""
    echo "========== PACKET LOSS 10% =========="

    sudo nsenter -t "$CPID" -n \
      tc qdisc replace dev eth1 root netem loss 10%

    sudo nsenter -t "$CPID" -n \
      tc qdisc show dev eth1

    tcp_test "LOSS_10PCT"
    udp_test "LOSS_10PCT"

    cleanup

    echo ""
    echo "========== HASIL AKHIR =========="

    sudo nsenter -t "$CPID" -n \
      tc qdisc show dev eth1

    echo ""
    echo "===== REKAP TCP ====="
    cat "$OUT/tcp-transfer-fixed.csv"

    echo ""
    echo "===== REKAP UDP BASELINE ====="
    cat "$OUT/udp-fixed-BASELINE.txt"

    echo ""
    echo "===== REKAP UDP LOSS 10% ====="
    cat "$OUT/udp-fixed-LOSS_10PCT.txt"

} 2>&1 | tee "$OUT/qos-batch-fixed.txt"

trap - EXIT

echo ""
echo "PENGUJIAN BATCH SELESAI"
