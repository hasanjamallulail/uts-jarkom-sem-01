#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan" || exit 1

CAP="evidence/soal3/capture"
PCAP="$CAP/tcp-transfer-loss-fixed.pcap"

echo "=============================================="
echo " UTS CS238 - ANALISIS TCP RETRANSMISSION"
echo "=============================================="

if [ ! -s "$PCAP" ]; then
    echo "ERROR: File PCAP tidak ditemukan."
    exit 1
fi

echo ""
echo "===== INFORMASI FILE CAPTURE ====="
ls -lh "$PCAP"

echo ""
echo "===== PEMERIKSAAN TSHARK ====="

if ! command -v tshark >/dev/null 2>&1; then
    echo "TShark belum tersedia."
    echo "Install dengan: sudo apt install tshark"
    echo "Tidak ada kesimpulan retransmission otomatis."
    exit 0
fi

echo ""
echo "===== TCP RETRANSMISSION ====="

tshark -r "$PCAP" \
    -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission || tcp.analysis.spurious_retransmission' \
    -T fields \
    -e frame.number \
    -e frame.time_relative \
    -e ip.src \
    -e tcp.srcport \
    -e ip.dst \
    -e tcp.dstport \
    -e tcp.seq \
    -e tcp.len \
    -e _ws.col.Info \
    > "$CAP/tcp-retransmission-analysis.txt"

cat "$CAP/tcp-retransmission-analysis.txt"

echo ""
echo "===== DUPLICATE ACK ====="

tshark -r "$PCAP" \
    -Y 'tcp.analysis.duplicate_ack' \
    -T fields \
    -e frame.number \
    -e frame.time_relative \
    -e ip.src \
    -e ip.dst \
    -e tcp.ack \
    -e _ws.col.Info \
    > "$CAP/tcp-duplicate-ack.txt"

cat "$CAP/tcp-duplicate-ack.txt"

echo ""
echo "===== TCP LOST SEGMENT ====="

tshark -r "$PCAP" \
    -Y 'tcp.analysis.lost_segment' \
    -T fields \
    -e frame.number \
    -e frame.time_relative \
    -e ip.src \
    -e ip.dst \
    -e _ws.col.Info \
    > "$CAP/tcp-lost-segment.txt"

cat "$CAP/tcp-lost-segment.txt"

echo ""
echo "===== REKAP JUMLAH ====="

RETRANS=$(wc -l < "$CAP/tcp-retransmission-analysis.txt")
DUPACK=$(wc -l < "$CAP/tcp-duplicate-ack.txt")
LOST=$(wc -l < "$CAP/tcp-lost-segment.txt")

echo "Retransmission : $RETRANS"
echo "Duplicate ACK   : $DUPACK"
echo "Lost Segment    : $LOST"

echo ""
echo "===== TCP THREE-WAY HANDSHAKE ====="

tshark -r "$PCAP" \
    -Y 'tcp.flags.syn == 1 || tcp.flags.fin == 1 || tcp.flags.reset == 1' \
    -T fields \
    -e frame.number \
    -e ip.src \
    -e tcp.srcport \
    -e ip.dst \
    -e tcp.dstport \
    -e _ws.col.Info \
    | head -n 20

echo ""
echo "=============================================="
echo " ANALISIS SELESAI"
echo "=============================================="
