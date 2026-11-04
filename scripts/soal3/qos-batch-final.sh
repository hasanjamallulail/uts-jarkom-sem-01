#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan"

OUT="evidence/soal3/qos"
CAP="evidence/soal3/capture"
CLIENT="clab-uts-PC-BR1"
SERVER="clab-uts-APP-SRV"

mkdir -p "$OUT" "$CAP"

command -v python3 >/dev/null || {
    echo "Python3 belum tersedia di Ubuntu host."
    exit 1
}

CPID=$(sudo docker inspect -f '{{.State.Pid}}' "$CLIENT")
SPID=$(sudo docker inspect -f '{{.State.Pid}}' "$SERVER")

cleanup() {
    sudo nsenter -t "$CPID" -n \
      tc qdisc del dev eth1 root 2>/dev/null || true

    sudo docker exec "$SERVER" \
      sh -c 'killall nc 2>/dev/null || true' \
      >/dev/null 2>&1 || true
}

CURRENT=$(sudo nsenter -t "$CPID" -n \
  tc qdisc show dev eth1)

if ! grep -q "qdisc noqueue" <<< "$CURRENT"; then
    echo "DIBATALKAN: qdisc awal bukan noqueue."
    echo "$CURRENT"
    exit 1
fi

trap cleanup EXIT INT TERM

echo "=========================================="
echo " UTS CS238 - QOS BATCH FINAL"
echo "=========================================="

echo ""
echo "===== PERSIAPAN FILE TCP 64 KiB ====="

sudo docker exec "$CLIENT" \
  sh -c 'dd if=/dev/urandom of=/tmp/qos-test.bin bs=1024 count=64 2>/dev/null'

EXPECTED=$(sudo docker exec "$CLIENT" \
  sha256sum /tmp/qos-test.bin | awk '{print $1}')

echo "SHA256 sumber: $EXPECTED"

tcp_test() {
    LABEL="$1"

    echo ""
    echo "===== TCP TRANSFER: $LABEL ====="

    sudo docker exec "$SERVER" \
      sh -c 'killall nc 2>/dev/null || true; : > /tmp/qos-received.bin'

    sudo docker exec -d "$SERVER" \
      sh -c 'nc -l -p 5002 > /tmp/qos-received.bin'

    sleep 1

    CAP_PID=""

    if [ "$LABEL" = "LOSS_10PCT" ]; then
        sudo timeout 12 \
          nsenter -t "$SPID" -n \
          tcpdump -i eth1 -nn -U \
          -w "$CAP/tcp-transfer-loss.pcap" \
          'host 10.10.20.10 and tcp port 5002' \
          2> "$CAP/tcp-transfer-loss-info.txt" &

        CAP_PID=$!
        sleep 1
    fi

    START=$(date +%s%N)

    sudo docker exec "$CLIENT" \
      sh -c 'nc -w 8 10.10.30.10 5002 < /tmp/qos-test.bin'

    NC_EXIT=$?
    END=$(date +%s%N)

    sleep 1

    BYTES=$(sudo docker exec "$SERVER" \
      wc -c < /tmp/qos-received.bin)

    RECEIVED=$(sudo docker exec "$SERVER" \
      sha256sum /tmp/qos-received.bin | awk '{print $1}')

    MS=$(( (END - START) / 1000000 ))

    if [ "$EXPECTED" = "$RECEIVED" ]; then
        INTEGRITY="VALID"
    else
        INTEGRITY="TIDAK_VALID"
    fi

    echo "Kondisi: $LABEL"
    echo "Waktu transfer: ${MS} ms"
    echo "Byte diterima: $BYTES"
    echo "Exit code Netcat: $NC_EXIT"
    echo "SHA256 penerima: $RECEIVED"
    echo "Integritas file: $INTEGRITY"

    if [ -n "$CAP_PID" ]; then
        wait "$CAP_PID" || true

        sudo tcpdump -nn \
          -r "$CAP/tcp-transfer-loss.pcap" \
          > "$CAP/tcp-transfer-loss.txt" 2>&1

        echo "Capture TCP tersimpan."
    fi

    echo "$LABEL,$MS,$BYTES,$NC_EXIT,$INTEGRITY" \
      >> "$OUT/tcp-transfer-summary.csv"
}

udp_test() {
    LABEL="$1"

    echo ""
    echo "===== UDP: $LABEL ====="

    sudo docker exec "$SERVER" \
      sh -c 'killall nc 2>/dev/null || true' \
      >/dev/null 2>&1 || true

    sudo nsenter -t "$SPID" -n \
      python3 -u scripts/soal3/udp_qos.py \
      server "$LABEL" --count 30 \
      > "$OUT/udp-$LABEL.txt" 2>&1 &

    UDP_PID=$!

    sleep 1

    sudo nsenter -t "$CPID" -n \
      python3 scripts/soal3/udp_qos.py \
      client "$LABEL" --count 30

    wait "$UDP_PID"
    UDP_EXIT=$?

    cat "$OUT/udp-$LABEL.txt"
    echo "Exit code penerima UDP: $UDP_EXIT"
}

echo "kondisi,waktu_ms,byte_diterima,exit_code,integritas" \
  > "$OUT/tcp-transfer-summary.csv"

{
    echo ""
    echo "========== KONDISI BASELINE =========="

    tcp_test "BASELINE"
    udp_test "BASELINE"

    echo ""
    echo "========== KONDISI DELAY 100 MS =========="

    sudo nsenter -t "$CPID" -n \
      tc qdisc replace dev eth1 root netem delay 100ms

    sudo nsenter -t "$CPID" -n \
      tc qdisc show dev eth1

    tcp_test "DELAY_100MS"

    cleanup

    echo ""
    echo "========== KONDISI LOSS 10% =========="

    sudo nsenter -t "$CPID" -n \
      tc qdisc replace dev eth1 root netem loss 10%

    sudo nsenter -t "$CPID" -n \
      tc qdisc show dev eth1

    tcp_test "LOSS_10PCT"
    udp_test "LOSS_10PCT"

    cleanup

    echo ""
    echo "========== VERIFIKASI AKHIR =========="

    sudo nsenter -t "$CPID" -n \
      tc qdisc show dev eth1

    echo ""
    echo "===== REKAP TRANSFER TCP ====="
    cat "$OUT/tcp-transfer-summary.csv"

    echo ""
    echo "===== FILE EVIDENCE ====="
    ls -lh "$OUT"/tcp-transfer* "$OUT"/udp-* \
      "$CAP"/tcp-transfer-loss* 2>/dev/null

} 2>&1 | tee "$OUT/qos-batch-final.txt"

trap - EXIT INT TERM

echo ""
echo "PENGUJIAN BATCH SELESAI"
