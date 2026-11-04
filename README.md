<div align="center">

# 🌐 UTS — Network Engineering & Troubleshooting with Containerlab

### Simulasi Jaringan Perusahaan • Routing • Transport Layer • QoS • Investigasi Gangguan

![Ubuntu](https://img.shields.io/badge/Ubuntu_Server-24.04.5_LTS-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-29.9.2-2496ED?logo=docker&logoColor=white)
![Containerlab](https://img.shields.io/badge/Containerlab-0.82.0-1475C2)
![FRRouting](https://img.shields.io/badge/FRRouting-10.4.1-176B45)
![Routing](https://img.shields.io/badge/Routing-Static_%7C_RIPv2_%7C_OSPF-6F42C1)

**Hasan Jamallulail** · **2611600244**  
Magister Ilmu Komputer · Fakultas Teknologi Informasi  
**Universitas Budi Luhur, Jakarta**  
**Penugasan:** Ujian Tengah Semester (UTS) — Containerlab  
**Dosen:** Dr. Akhmad Unggul

</div>

---

## 📌 Ringkasan

Repository ini mendokumentasikan implementasi dan investigasi jaringan perusahaan virtual yang memiliki **kantor pusat (HQ)**, **dua cabang (BR1 dan BR2)**, serta **pusat data (DC)**. Lingkungan dibangun menggunakan Ubuntu Server, Docker, Containerlab, Linux Bridge, dan FRRouting (FRR).

Kasus yang diinvestigasi adalah akses host cabang ke server pusat yang kadang gagal, disertai pemulihan koneksi yang tidak selalu langsung terjadi. Analisis **tidak mengasumsikan bahwa semua gangguan berasal dari routing**: kondisi link, alamat IP, forwarding, layanan TCP/UDP, dan kualitas jaringan diperiksa melalui bukti pengujian.

**Prinsip eksperimen:** Prediksi → Pengukuran → Observasi → Analisis → Kesimpulan. Hasil terukur dipisahkan dari interpretasi dan batasan eksperimen.

### Cakupan

- **14 node logis:** 4 router FRR, 4 switch Linux Bridge, 4 client, dan 2 server.
- **13 koneksi logis**, dengan tiga transit antarrrouter.
- **4 subnet LAN** dan **3 subnet transit /30**.
- Eksperimen **Static Routing, RIP versi 2, OSPF Area 0, TCP, UDP, ICMP, packet capture, delay, packet loss, dan uji regresi**.
- Konfigurasi, script pengujian, dan bukti historis disimpan untuk kebutuhan audit.

## 🏗️ Topologi

```text
                                DATA CENTER
                               10.10.30.0/24
                                 APP-SRV (.10)
                                 DNS-SRV (.53)
                                      |
                                    SW-DC
                                      |
                                     R-DC
                                      |
                                10.0.0.4/30
                                      |
 BRANCH 1                        R-HQ (HUB)                         BRANCH 2
 10.10.20.0/24                   /    |    \                       10.10.40.0/24
    PC-BR1                       /     |     \                          PC-BR2
       |                        /      |      \                            |
     SW-BR1                   /      SW-HQ      \                        SW-BR2
       |                     /      /     \      \                          |
     R-BR1 -----------------/   PC-HQ1   PC-HQ2   \----------------------- R-BR2
             10.0.0.0/30         HQ LAN             10.0.0.8/30
                              10.10.10.0/24
```

Diagram ini ilustrasi logis, bukan pengganti definisi antarmuka pada berkas YAML. Setiap cabang hanya mempunyai **satu link transit ke HQ**; tidak tersedia jalur cadangan pada topologi yang diuji.

| Jenis | Node | Jumlah |
|---|---|---:|
| Router FRRouting | `R-HQ`, `R-BR1`, `R-BR2`, `R-DC` | 4 |
| Switch berbasis Linux Bridge | `SW-HQ`, `SW-BR1`, `SW-BR2`, `SW-DC` | 4 |
| Client Alpine | `PC-HQ1`, `PC-HQ2`, `PC-BR1`, `PC-BR2` | 4 |
| Server Alpine | `APP-SRV`, `DNS-SRV` | 2 |
| **Total** | **14 node logis; 13 link** | **14** |

> Containerlab/Docker menjalankan **10 container** (4 router + 6 endpoint). Empat switch adalah Linux Bridge pada host, sehingga tidak muncul sebagai container Docker.

### Pengalamatan IPv4

| Segmen | Subnet | Gateway/router LAN |
|---|---|---|
| HQ | `10.10.10.0/24` | `10.10.10.1` |
| BR1 | `10.10.20.0/24` | `10.10.20.1` |
| BR2 | `10.10.40.0/24` | `10.10.40.1` |
| DC | `10.10.30.0/24` | `10.10.30.1` |

| Transit | Network | Sisi pertama | Sisi kedua |
|---|---|---|---|
| HQ ↔ BR1 | `10.0.0.0/30` | R-HQ `10.0.0.1` (`eth1`) | R-BR1 `10.0.0.2` (`eth1`) |
| HQ ↔ DC | `10.0.0.4/30` | R-HQ `10.0.0.5` (`eth2`) | R-DC `10.0.0.6` (`eth1`) |
| HQ ↔ BR2 | `10.0.0.8/30` | R-HQ `10.0.0.9` (`eth3`) | R-BR2 `10.0.0.10` (`eth1`) |

| Endpoint | IPv4 | Gateway |
|---|---|---|
| `PC-HQ1` | `10.10.10.10/24` | `10.10.10.1` |
| `PC-HQ2` | `10.10.10.11/24` | `10.10.10.1` |
| `PC-BR1` | `10.10.20.10/24` | `10.10.20.1` |
| `PC-BR2` | `10.10.40.10/24` | `10.10.40.1` |
| `APP-SRV` | `10.10.30.10/24` | `10.10.30.1` |
| `DNS-SRV` | `10.10.30.53/24` | `10.10.30.1` |

## 🧰 Lingkungan Pengujian

| Komponen | Versi yang dicatat |
|---|---|
| Ubuntu Server | 24.04.5 LTS |
| Docker Engine | 29.9.2 |
| Containerlab | 0.82.0 |
| FRRouting | 10.4.1 |
| Alpine Linux (endpoint) | 3.20 |

**Utilitas:** `vtysh`, `ping`, `traceroute`, `tcpdump`, `nc`/Netcat, dan Linux `tc netem`.

## 🧪 Hasil Pengerjaan Soal 1–5

### Soal 1 — Routing dan Kegagalan Jalur

| Bagian | Kegiatan | Observasi utama |
|---|---|---|
| **1(i)** | Mengonfigurasi routing antarsubnet, memeriksa next hop, routing table, konektivitas | Jalur BR1 → APP-SRV melewati R-BR1 → R-HQ → R-DC |
| **1(ii)** | Menguji *longest-prefix match* menggunakan prefix `/24` dan `/32` | Route `/32` lebih spesifik; pada uji ini next hop keduanya sama, sehingga jalur tidak berubah |
| **1(iii)** | Memutus dan memulihkan link R-BR1 ↔ R-HQ | BR1 → APP-SRV kehilangan seluruh 5 ping ketika link down; BR2 tetap dapat mengakses server; setelah link pulih, BR1 kembali berhasil |
| **1(iv)** | Membandingkan Static, RIP v2, dan OSPF | Perbedaan konfigurasi, pemilihan jalur, respons gangguan, dan risiko dianalisis dari konfigurasi serta bukti pengujian |
| **1(v)** | Merekomendasikan pendekatan routing | OSPF Area 0 dipilih sebagai rancangan utama, dengan catatan perlunya redundansi |

**Catatan:** Saat link tunggal BR1–HQ terputus, routing statis dapat memperlihatkan route rekursif ke interface manajemen Docker (`eth0`). Route yang masih tampil pada tabel **tidak membuktikan** paket dapat dikirim ke server melalui jalur data yang valid.

### Soal 2 — RIP vs OSPF

| Bagian | Kegiatan | Observasi utama |
|---|---|---|
| **2(i)** | Menerapkan RIP v2 dan OSPF secara terpisah | RIP menampilkan route `R`, OSPF menampilkan route `O`; neighbor OSPF akhir `Full/-` |
| **2(ii)** | Mensimulasikan link failure BR1–HQ | Kedua protokol tidak dapat menyediakan jalur alternatif ketika link tunggal putus |
| **2(iii)** | Pengujian berulang dan audit konvergensi | Tiga pengulangan ping pada kondisi OSPF normal berhasil; bukan pengukuran waktu konvergensi yang setara |
| **2(iv)** | Evaluasi kontekstual RIP dan OSPF | OSPF lebih sesuai untuk rencana pertumbuhan, tetapi tidak otomatis lebih baik pada setiap kondisi |

RIP v2 menggunakan *hop count* (administrative distance 120 pada bukti routing), sedangkan OSPF menggunakan *cost* (administrative distance 110 pada bukti routing). Setelah percobaan pemulihan link, pengaturan **`ip ospf network point-to-point`** diterapkan secara konsisten pada semua interface transit untuk menstabilkan adjacency OSPF.

> **Keterbatasan penting:** Log link failure mencatat kegagalan ping segera setelah pemulihan pada beberapa percobaan. Pemeriksaan lanjutan menunjukkan konektivitas dan adjacency OSPF akhirnya pulih. Waktu konvergensi RIP dan OSPF **belum diukur dengan prosedur dan titik waktu yang setara**, sehingga tidak diklaim OSPF lebih cepat berdasarkan eksperimen ini.

### Soal 3 — Transport Layer dan QoS

| Bagian | Kegiatan | Bukti utama |
|---|---|---|
| **3(i)** | TCP port 5000 aktif dan mati; dibandingkan dengan ICMP | Handshake `SYN → SYN/ACK → ACK`; saat tidak listening muncul `RST` |
| **3(ii)** | UDP port 5001 aktif, mati, dan tanpa respons aplikasi | Baseline 100/100 datagram diterima; port tertutup menghasilkan ICMP port unreachable; tidak ada balasan aplikasi bukan bukti bahwa datagram tidak diterima |
| **3(iii)** | Analisis `tcpdump` dan file `.pcap` | Teridentifikasi IP/port, TCP handshake, reset, retransmission, duplicate ACK, indikasi segmen sebelumnya tidak tertangkap, dan ICMP |
| **3(iv)** | Eksperimen `tc netem` delay 100 ms dan loss 10% | Delay menaikkan RTT/waktu respons; loss terukur pada aplikasi UDP dan paket ICMP |
| **3(v)** | Investigasi ping sukses tetapi TCP gagal | Diuji hipotesis service tidak listening, firewall/ACL, dan jalur pergi/pulang routing |

#### Beberapa pengukuran yang tercatat

| Metrik | Baseline | Kondisi pengujian |
|---|---:|---:|
| ICMP PC-BR1 → APP-SRV | 20/20 sukses, RTT rata-rata **0,075 ms** | Pada delay 100 ms, pengukuran RTT meningkat; lihat log sumber |
| Transfer TCP 256 KiB | **45 ms** | **244 ms** dengan delay 100 ms; **46 ms** pada uji loss 10% yang dicatat |
| Integritas transfer TCP | `VALID` | `VALID` pada ketiga skenario tercatat |
| UDP datagram diterima | **100/100** | **94/100** pada simulasi loss 10% (loss aplikasi **6%**) |
| Respons TCP (5 pengulangan) | **46–55 ms** | **245–248 ms** saat delay 100 ms |

Angka tersebut berasal dari sesi pengujian virtual yang terdokumentasi, bukan estimasi performa jaringan nyata. Analisis TCP retransmission dan duplicate ACK merujuk pada rekaman khusus yang menunjukkan kejadian tersebut; tidak digeneralisasikan ke seluruh eksperimen.

### Soal 4 — Investigasi Gangguan Terintegrasi

Skenario melibatkan **dua komponen/lapisan**: (1) route khusus `unreachable 10.10.30.10` pada client, dan (2) server TCP port **5504** yang tidak aktif.

| Bagian | Kegiatan | Hasil |
|---|---|---|
| **4(i)** | Mencatat baseline, pemicu, gejala, dampak, dan cara mengulang | Pada baseline, ICMP dan TCP berhasil; gangguan memutus akses aplikasi |
| **4(ii)** | Menguji tiga hipotesis | H1 masalah adjacency OSPF tidak didukung; H2 route unreachable didukung; H3 layanan TCP tidak listening didukung |
| **4(iii)** | Diagnosis dan kontrol variabel | Routing diperbaiki terlebih dahulu, lalu status TCP diuji terpisah |
| **4(iv)** | Pemulihan dan pembuktian | Setelah perbaikan route, ping berhasil tetapi TCP tetap gagal; TCP berhasil sesudah service diaktifkan |
| **4(v)** | Uji regresi | ICMP HQ/BR1/BR2 dan akses DNS-SRV sukses; setelah layanan 5504 diaktifkan ulang, uji TCP BR1 serta BR2 berhasil |

Layanan TCP port 5504 adalah **layanan sementara eksperimen**, bukan layanan yang dijanjikan aktif permanen. Pada tahap cleanup, port 5504 ditutup kembali, sementara port 5000 tetap aktif sebagaimana verifikasi terakhir.

### Soal 5 — Evaluasi Arsitektur dan Rekomendasi

| Bagian | Fokus | Kesimpulan |
|---|---|---|
| **5(i)** | Tiga risiko teknis | R-HQ sebagai *single point of failure*; tidak ada link cadangan; kesalahan route atau layanan dapat memutus aplikasi |
| **5(ii)** | Usulan peningkatan arsitektur | Redundansi, monitoring, standardisasi konfigurasi, skalabilitas, evaluasi kualitas aplikasi, dan otomasi operasional |
| **5(iii)** | Indikator keberhasilan | ICMP loss, RTT, keberhasilan TCP, adjacency OSPF, dan penerimaan datagram UDP |
| **5(iv)** | Keputusan desain dan trade-off | OSPF Area 0 dipilih dengan konsekuensi kompleksitas konfigurasi dan kebutuhan monitoring |

#### Indikator keberhasilan yang diusulkan

| Indikator | Metode | Target lab yang diusulkan |
|---|---|---|
| Packet loss ICMP | `ping -c 20` BR1 → APP-SRV | 0% dalam kondisi normal |
| RTT rata-rata | Statistik min/avg/max `ping` | < 1 ms di lingkungan lab normal |
| Ketersediaan TCP | Netcat + respons aplikasi | Berhasil dari kedua cabang **saat service aktif** |
| OSPF neighbor | `vtysh -c 'show ip ospf neighbor'` | Semua adjacency `FULL` |
| UDP diterima | Hitung datagram pada aplikasi | ≥ 99 dari 100 dalam kondisi normal |

Target merupakan **kriteria usulan untuk pengujian lab**, bukan SLA produksi.

## 🚀 Menjalankan Lab

### Prasyarat

- Linux host dengan Docker Engine dan Containerlab terpasang.
- Image container FRRouting `quay.io/frrouting/frr:10.4.1` dan Alpine `alpine:3.20` tersedia atau dapat ditarik.
- Izin menjalankan Docker/Containerlab dan membuat Linux Bridge.
- Pastikan tidak ada lab bernama `uts` lain yang sedang aktif.

### 1. Clone repository

```bash
git clone git@github.com:hasanjamallulail/uas-jarkom-sem1.git
cd uas-jarkom-sem1
```

> Clone SSH memerlukan SSH key yang sudah terdaftar di akun GitHub. Untuk repo private, akun pengguna harus memiliki akses.

### 2. Periksa versi

```bash
cat /etc/os-release | head
sudo docker version
containerlab version
```

### 3. Deploy OSPF (varian utama untuk verifikasi terakhir)

```bash
sudo containerlab deploy -t topology-ospf.clab.yml
sudo containerlab inspect -t topology-ospf.clab.yml
sudo docker ps --format 'table {{.Names}}\t{{.Status}}'
```

### 4. Verifikasi OSPF dan routing

```bash
sudo docker exec clab-uts-R-HQ vtysh -c 'show ip ospf neighbor'
sudo docker exec clab-uts-R-HQ vtysh -c 'show ip route ospf'
sudo docker exec clab-uts-R-BR1 vtysh -c 'show ip route 10.10.30.0/24'
```

Pada kondisi normal yang telah diuji, R-HQ memiliki tiga neighbor OSPF `FULL`, sedangkan R-BR1, R-BR2, dan R-DC masing-masing memiliki satu neighbor `FULL` menuju R-HQ.

### 5. Uji konektivitas dasar

```bash
sudo docker exec clab-uts-PC-BR1 ping -c 5 10.10.30.10
sudo docker exec clab-uts-PC-BR2 ping -c 5 10.10.30.10
sudo docker exec clab-uts-PC-HQ1 ping -c 5 10.10.30.10
sudo docker exec clab-uts-PC-BR1 ping -c 3 10.10.30.53
```

### 6. Menghentikan atau berpindah varian

```bash
sudo containerlab destroy -t topology-ospf.clab.yml
```

Untuk menggunakan RIP secara terpisah:

```bash
sudo containerlab deploy -t topology-rip.clab.yml
sudo docker exec clab-uts-R-HQ vtysh -c 'show ip protocols'
sudo docker exec clab-uts-R-HQ vtysh -c 'show ip route rip'
sudo containerlab destroy -t topology-rip.clab.yml
```

**Jangan men-deploy dua varian bernama `uts` secara bersamaan.** Gunakan konfigurasi masing-masing pada `configs/rip/` dan `configs/ospf/`.

### 7. Mengulang eksperimen dan melihat evidence

```bash
find scripts -type f | sort
find evidence -type f | sort
```

Script simulasi kegagalan dapat **memutus interface, memodifikasi routing, mengaktifkan/menonaktifkan layanan, atau memasang netem**. Baca script sebelum dijalankan; jalankan hanya dalam lingkungan uji dan pastikan cleanup/rollback setelah eksperimen. File `.pcap` dapat dianalisis dengan `tcpdump -nn -r nama-file.pcap` atau Wireshark di komputer lokal.

## 🗂️ Struktur Repository

```text
.
├── README.md
├── topology.clab.yml
├── topology-next.clab.yml
├── topology-rip.clab.yml
├── topology-ospf.clab.yml
├── configs/
│   ├── R-HQ/  R-BR1/  R-BR2/  R-DC/
│   ├── static-backup/
│   ├── rip/
│   └── ospf/
├── scripts/
│   ├── final/
│   ├── soal3/
│   └── ...
├── evidence/
│   ├── soal1/
│   ├── soal2/
│   ├── soal3/
│   ├── soal4/
│   ├── soal5/
│   └── laporan/
└── laporan-final/            # jika tersedia di checkout lokal
    ├── dokumen/
    └── screenshots/
```

**Catatan pengumpulan:** `report.pdf` dan screenshot **belum diverifikasi sebagai file yang tersedia di repository**. Narasi dan gambar yang dibahas dalam percakapan tidak otomatis menjadi berkas dalam GitHub. Direktori kosong juga tidak dilacak Git. Sebelum menyerahkan tugas, lengkapi laporan PDF dan gambar bukti, lalu tambahkan melalui commit tersendiri.

## 🔍 Batasan dan Kejujuran Pengukuran

- Topologi *hub-and-spoke* tidak menyediakan link cadangan untuk BR1 ↔ HQ; **failover ke jalur lain belum bisa dibuktikan**.
- R-HQ adalah titik ketergantungan utama. Kegagalan total HQ berpotensi berdampak pada berbagai lokasi, tetapi skenario tersebut tidak diklaim telah diuji secara menyeluruh.
- RIP/OSPF pernah mengalami kegagalan komunikasi segera setelah pemulihan link; pada pemeriksaan berikutnya konektivitas dapat kembali normal. **Durasi konvergensi tidak dihitung secara presisi atau setara.**
- Uji QoS menggunakan lingkungan virtual dan `netem`; hasilnya dipengaruhi host, timing, ukuran sampel, dan metode pengukuran.
- TCP retransmission/duplicate ACK hanya diklaim untuk capture yang memang menampilkannya.
- Status `FULL` OSPF membuktikan adjacency antarrouter pada titik waktu pemeriksaan, **bukan** menjamin seluruh layanan aplikasi tersedia.
- Layanan sementara port 5504 ditutup setelah uji regresi. Ketersediaan service harus diuji ulang jika diperlukan.

## ✅ Kesimpulan

Jaringan yang telah dikonfigurasi dapat meneruskan trafik antarsubnet selama jalur dan layanan tersedia. Eksperimen menunjukkan bahwa gangguan akses aplikasi dapat berasal dari **routing, link, dan layanan transport/aplikasi** secara terpisah maupun bersamaan. Penggunaan OSPF Area 0 sesuai sebagai dasar pengembangan jaringan ini, namun **monitoring, standardisasi konfigurasi, serta penambahan redundansi** tetap diperlukan untuk meningkatkan keandalan.

---

<div align="center">

**Universitas Budi Luhur — Jakarta**  
Hasan Jamallulail · 2611600244  
Magister Ilmu Komputer · Fakultas Teknologi Informasi  
**UTS Containerlab · Dosen: Dr. Akhmad Unggul**

*Dokumentasi pembelajaran dan pengujian jaringan virtual.*

</div>
