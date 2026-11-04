#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan" || exit 1

OUT="evidence/soal3"
CAP="$OUT/capture"
QOS="$OUT/qos"

echo "=========================================="
echo " UTS CS238 - FINALISASI SOAL 3"
echo "=========================================="

echo ""
echo "===== 1. PEMERIKSAAN TCP PACKET CAPTURE ====="

PCAP="$CAP/tcp-transfer-loss-fixed.pcap"

if [ -s "$PCAP" ]; then

    sudo tcpdump -nn -tt -r "$PCAP" \
      > "$CAP/tcp-analysis-final.txt" 2>&1

    echo "Capture ditemukan dan dibaca."

    echo ""
    echo "===== CONTOH PAKET TCP ====="
    head -n 15 "$CAP/tcp-analysis-final.txt"

    echo ""
    echo "===== JUMLAH PAKET BERDASARKAN FLAG ====="

    for flag in '[S]' '[S.]' '[P.]' '[F.]' '[R.]'; do
        COUNT=$(grep -Fc "Flags $flag" \
          "$CAP/tcp-analysis-final.txt" || true)

        echo "Flags $flag : $COUNT"
    done

    if command -v tshark >/dev/null 2>&1; then

        echo ""
        echo "===== ANALISIS RETRANSMISSION TSHARK ====="

        tshark -r "$PCAP" \
          -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission || tcp.analysis.spurious_retransmission' \
          -T fields \
          -e frame.number \
          -e ip.src \
          -e ip.dst \
          -e tcp.analysis.retransmission \
          > "$CAP/tcp-retransmission-final.txt" \
          2> "$CAP/tshark-info.txt" || true

        cat "$CAP/tcp-retransmission-final.txt"

        if [ ! -s "$CAP/tcp-retransmission-final.txt" ]; then
            echo "Tidak ada retransmission yang ditandai tshark."
        fi

    else
        echo ""
        echo "tshark belum tersedia."
        echo "Retransmission belum dapat disimpulkan otomatis."
        echo "Analisis manual dapat dilakukan dari file PCAP."
    fi

else
    echo "File capture TCP belum ditemukan."
fi

echo ""
echo "===== 2. REKAP HASIL TCP ====="
cat "$QOS/tcp-transfer-fixed.csv"

echo ""
echo "===== 3. REKAP HASIL UDP ====="

cat "$QOS/udp-fixed-BASELINE.txt"
cat "$QOS/udp-fixed-LOSS_10PCT.txt"

echo ""
echo "===== 4. VERIFIKASI QDISC ====="

PID=$(sudo docker inspect -f '{{.State.Pid}}' \
  clab-uts-PC-BR1)

sudo nsenter -t "$PID" -n \
  tc qdisc show dev eth1

echo ""
echo "===== 5. JUMLAH FILE EVIDENCE ====="
find "$OUT" -type f | wc -l

echo ""
echo "===== 6. BUAT BACKUP FINAL SOAL 3 ====="

mkdir -p "$HOME/UTS-BACKUP"

TANGGAL=$(date +%Y%m%d_%H%M%S)
BACKUP="$HOME/UTS-BACKUP/SOAL3-CS238-$TANGGAL.zip"

if command -v zip >/dev/null 2>&1; then

    zip -q -r "$BACKUP" \
      scripts/soal3 evidence/soal3

    echo "BACKUP: $BACKUP"

    echo ""
    echo "===== 7. VERIFIKASI BACKUP ====="

    unzip -t "$BACKUP" | tail -n 2

    ls -lh "$BACKUP"

else
    echo "Program zip belum tersedia."
fi

echo ""
echo "=========================================="
echo " FINALISASI SOAL 3 SELESAI"
echo "=========================================="
