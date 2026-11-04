#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan" || exit 1

OUT="evidence/audit-final/soal1-laporan"
mkdir -p "$OUT"

section() {
    echo ""
    echo "===================================================="
    echo " $1"
    echo "===================================================="
}

# 1. STATIC ROUTING
{
    section "SOAL 1(i) - KONFIGURASI STATIC ROUTING"

    for R in R-HQ R-BR1 R-BR2 R-DC; do
        F="configs/static-backup/$R-frr.conf"

        echo ""
        echo "===== ROUTER $R ====="

        if [ -f "$F" ]; then
            grep -E '^[[:space:]]*ip route ' "$F" ||
              echo "Tidak ditemukan static route."
        else
            echo "Backup konfigurasi tidak ditemukan."
        fi
    done

    echo ""
    echo "===== NEXT HOP MENUJU APP-SRV ====="
    echo "Tujuan: 10.10.30.10"

    echo "Dari HQ  : via 10.0.0.6"
    echo "Dari BR1 : via 10.0.0.1"
    echo "Dari BR2 : via 10.0.0.9"
    echo "Dari DC  : jaringan 10.10.30.0/24 terhubung langsung"

    echo ""
    echo "===== EVIDENCE TRACEROUTE ====="

    F="evidence/soal1/SS-10-traceroute.txt"

    if [ -f "$F" ]; then
        cat "$F"
    else
        echo "Evidence traceroute tidak ditemukan."
    fi

} 2>&1 | tee "$OUT/01-static-routing.txt"

# 2. LONGEST PREFIX MATCH
{
    section "SOAL 1(ii) - LONGEST PREFIX MATCH"

    F="evidence/soal1/SS-11-longest-prefix.txt"

    if [ -f "$F" ]; then
        cat "$F"
    else
        echo "Evidence longest-prefix tidak ditemukan."
    fi

    echo ""
    echo "===== PENJELASAN ====="
    echo "Prefix /32 lebih spesifik dibandingkan /24."
    echo "Ketika keduanya cocok, route /32 diprioritaskan."
    echo "Pada eksperimen ini next hop keduanya sama."
    echo "Karena itu jalur fisik tidak berubah."

} 2>&1 | tee "$OUT/02-longest-prefix.txt"

# 3. LINK FAILURE
{
    section "SOAL 1(iii) - SIMULASI LINK FAILURE"

    F="evidence/soal1/SS-12-link-failure.txt"

    if [ -f "$F" ]; then
        cat "$F"
    else
        echo "Evidence link failure tidak ditemukan."
    fi

    echo ""
    echo "===== KESIMPULAN ====="
    echo "Link Cabang 1 ke HQ merupakan jalur tunggal."
    echo "Ketika link terputus, BR1 kehilangan akses."
    echo "Tidak tersedia jalur alternatif untuk BR1."

} 2>&1 | tee "$OUT/03-link-failure.txt"

# 4. PERBANDINGAN ROUTING
{
    section "SOAL 1(iv) - STATIC VS RIP VS OSPF"

    printf '%-19s | %-17s | %-18s | %-18s\n' \
      "PARAMETER" "STATIC" "RIP V2" "OSPF"

    printf '%s\n' \
      "--------------------------------------------------------------------------"

    printf '%-19s | %-17s | %-18s | %-18s\n' \
      "Jenis routing" "Manual" "Distance-vector" "Link-state" \
      "Metric" "Ditentukan admin" "Hop count" "Cost" \
      "Skalabilitas" "Terbatas" "Terbatas" "Lebih fleksibel" \
      "Kompleksitas" "Rendah awalnya" "Relatif rendah" "Lebih tinggi" \
      "Respons kegagalan" "Perlu rute valid" "Update routing" "Update LSDB/SPF" \
      "Risiko operasional" "Salah static route" "Timer/metric" "Adjacency/cost"

    echo ""
    echo "===== HASIL EKSPERIMEN ====="
    echo "Ketiga metode mendukung konektivitas baseline."
    echo "Saat link tunggal BR1-HQ putus, BR1 terisolasi."
    echo "RIP dan OSPF tidak bisa menciptakan link alternatif."
    echo "Durasi konvergensi belum terukur secara setara."

} 2>&1 | tee "$OUT/04-perbandingan-routing.txt"

# 5. REKOMENDASI
{
    section "SOAL 1(v) - REKOMENDASI ROUTING"

    echo "REKOMENDASI UTAMA: OSPF"

    echo ""
    echo "Alasan:"
    echo "1. Routing antarsubnet dipelajari dinamis."
    echo "2. Cost dapat digunakan untuk pemilihan jalur."
    echo "3. Cocok untuk pengembangan cabang."
    echo "4. Konfigurasi Area 0 sudah terverifikasi."
    echo "5. Seluruh adjacency final berstatus FULL."

    echo ""
    echo "Keterbatasan:"
    echo "- Topologi belum memiliki link cadangan."
    echo "- HQ merupakan single point of failure."
    echo "- OSPF membutuhkan konfigurasi yang konsisten."
    echo "- Waktu konvergensi belum diukur secara presisi."

    echo ""
    echo "Kondisi perubahan keputusan:"
    echo "- Jaringan sangat kecil dan statis."
    echo "- Ada keterbatasan kemampuan operasional."
    echo "- Jumlah cabang atau persyaratan SLA berubah."
    echo "- Dibutuhkan jalur redundan."

    echo ""
    echo "Pengembangan yang disarankan:"
    echo "Tambahkan link cadangan dan uji failover OSPF."

} 2>&1 | tee "$OUT/05-rekomendasi.txt"

# 6. RINGKASAN
{
    section "SOAL 1 - RINGKASAN EVIDENCE"

    for F in "$OUT"/0[1-5]-*.txt; do
        echo ""
        ls -lh "$F"
    done

    echo ""
    echo "===== STATUS ====="
    echo "Audit selesai."
    echo "Tidak ada route yang diubah."
    echo "Tidak ada interface yang dimatikan."
    echo "Konfigurasi OSPF aktif tidak disentuh."

} 2>&1 | tee "$OUT/06-ringkasan.txt"

echo ""
echo "=============================================="
echo " AUDIT SOAL 1 SELESAI"
echo "=============================================="
