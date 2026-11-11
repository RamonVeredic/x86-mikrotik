# Instalasi MikroTik HCC0-4FJR di Proxmox

Paket ini menjalankan **instalasi RouterOS yang sudah ada**, tanpa memasang ulang RouterOS. Image mandiri `HCC0-4FJR.qcow2` berasal dari SSD asli sebelum boot pertama melalui VM. Kapasitas virtualnya 14,8 GiB; ukuran file sekitar 264 MB. Kondisi konfigurasi di image mengikuti waktu backup tersebut, bukan konfigurasi terbaru setelah VM dipakai.

Software ID **HCC0-4FJR** dan lisensi **Level 6** sudah terverifikasi pada salinan backup dan SSD fisik ketika identitas disk yang benar dipakai. Nama file saja tidak mempertahankan lisensi: model dan serial disk harus mengikuti pengaturan di bawah. Periksa lisensi kembali pada host tujuan.

## 1. Yang perlu disiapkan

- Host Proxmox VE x86-64 dengan virtualisasi CPU aktif dan akses root melalui Shell/SSH. Pengujian sebelumnya menggunakan QEMU 9.2.0.
- VM ID yang belum digunakan, misalnya `102`. VM `100` dan `101` sudah ada pada host asal.
- Minimal 1 GB RAM dan 2 vCPU untuk konfigurasi contoh.
- Storage Proxmox yang aktif dan mendukung **Disk image**, misalnya `local-lvm`. Sediakan kapasitas virtual minimal 16 GiB beserta ruang tambahan sesuai kebutuhan. File QCOW2 yang kecil bukan batas pemakaian disk setelah VM berjalan.
- Seluruh folder paket ini, terutama image dan script.
- Akses Console Proxmox dan akun MikroTik yang sudah ada. Password tidak disimpan di panduan.
- Untuk passthrough kartu fisik: dukungan VT-d/AMD-Vi, IOMMU aktif, dan kartu yang tidak sedang dipakai jaringan manajemen host.

**Tentang container:** RouterOS pada image ini membutuhkan **VM QEMU/KVM**, bukan container LXC atau Docker. Wadah yang disiapkan adalah VM dengan BIOS, CPU, RAM, dan disk sendiri. Tidak perlu membuat CT atau mengunduh template container.

## 2. Lokasi dan isi paket

Lokasi pada host asal:

```text
/root/HCC0-4FJR/
├── HCC0-4FJR.qcow2
├── INSTALASI.md
├── README.txt
├── buat-vm.sh
└── SHA256SUMS
```

Untuk host lain, salin folder tersebut, misalnya melalui SCP dari komputer yang bisa mengakses host sumber dan tujuan:

```bash
scp -r /root/HCC0-4FJR root@IP_HOST_TUJUAN:/root/
```

Ganti `IP_HOST_TUJUAN` dengan alamat host sebenarnya. Perintah contoh dijalankan dari mesin yang memiliki folder sumber tersebut.

Periksa kelengkapan dan image pada host tujuan:

```bash
cd /root/HCC0-4FJR
sha256sum -c SHA256SUMS
qemu-img info HCC0-4FJR.qcow2
qemu-img check HCC0-4FJR.qcow2
pvesm status
qm list
```

Image ini tidak mempunyai backing file sehingga dapat dipindahkan sendiri. Script dan panduan disertakan supaya pengaturan disk tidak terlewat.

## 3. Menyiapkan VM secara otomatis

Jalankan di Shell Proxmox sebagai root, setelah memastikan ID `102` belum dipakai:

```bash
bash /root/HCC0-4FJR/buat-vm.sh 102 local-lvm
```

Ganti `102` dan `local-lvm` sesuai host. Script memakai lokasi image relatif terhadap folder script, sehingga folder paket boleh dipindahkan.

Script akan:

1. Memeriksa ID dan menolak mengubah VM yang sudah ada.
2. Membuat VM dengan Q35, SeaBIOS, RAM 1 GB, dan 2 vCPU.
3. Mengimpor image menjadi disk milik VM pada storage tujuan.
4. Memasang disk sebagai SATA0, mengatur serial dan model, serta memilih SATA0 sebagai disk boot.
5. Meninggalkan VM dalam keadaan mati, tanpa jaringan dan tanpa passthrough PCI.

Image sumber tetap tersimpan. Jika proses gagal setelah VM dibuat, periksa `qm config 102` sebelum mengulang; script sengaja tidak menghapus VM atau disk secara otomatis.

## 4. Pengaturan identitas disk yang harus dipertahankan

| Pengaturan | Nilai |
| --- | --- |
| BIOS | SeaBIOS |
| Machine | q35 |
| Disk boot | SATA0 |
| Model disk QEMU | `SSD16G` |
| Serial disk | `SZHYPO1611140212411` |
| Software ID yang diharapkan | `HCC0-4FJR` |
| Level lisensi yang diharapkan | `6` |

Untuk VM baru hasil script, periksa:

```bash
qm config 102
```

Bagian pentingnya:

```text
args: -set device.sata0.model=SSD16G
bios: seabios
boot: order=sata0
machine: q35
sata0: <volume-hasil-impor>,serial=SZHYPO1611140212411,ssd=1,...
```

Pada pengujian, menyajikan disk dengan model bawaan QEMU menyebabkan Software ID berbeda dan lisensi tidak dikenali. Setelah model menjadi `SSD16G`, Software ID lama dan Level 6 dikenali kembali tanpa memasukkan kunci baru atau memerlukan internet.

## 5. Boot dan periksa lisensi

```bash
qm start 102
```

Buka **VM 102 → Console**, lalu login memakai akun yang tersimpan dalam instalasi MikroTik. Jalankan:

```routeros
/system license print
```

Hasil yang diharapkan:

```text
software-id: HCC0-4FJR
     nlevel: 6
```

Jika hasil berbeda, shutdown VM secara normal dan periksa model, serial, serta disk boot. Jangan format, Netinstall, atau menulis ulang SSD asli untuk mencoba memperbaikinya. Internet saja tidak otomatis mengembalikan identitas disk.

## 6. Menyiapkan jaringan atau passthrough PCI

Periksa lisensi dari Console dahulu. Konfigurasi router lama sudah ada di image; periksa pemetaan interface sebelum menghubungkan VM ke jaringan produksi.

### Pilihan A: kartu jaringan virtual

Jika ingin memakai bridge Proxmox, periksa bridge yang tersedia lalu tambahkan NIC pada VM baru, misalnya:

```bash
qm shutdown 102 --timeout 30
qm set 102 --net0 virtio,bridge=vmbr0
```

`vmbr0` adalah contoh dan harus sesuai host. Sesuaikan konfigurasi interface MikroTik karena NIC virtual mungkin berbeda dari kartu lama.

### Pilihan B: kartu PCI fisik

Pada host asal, kartu Intel 82576 dual-port adalah:

```text
0000:1a:00.0
0000:1a:00.1
```

Keduanya berada pada grup IOMMU yang sama. VM 100 sudah dikonfigurasi memakai kartu ini; pastikan VM 100 mati dan kartu tidak dipakai VM lain sebelum memakainya pada VM pengganti.

Periksa perangkat dan grup IOMMU pada host yang dipakai:

```bash
lspci -nnk
ls -l /sys/kernel/iommu_groups/*/devices/
```

Untuk alamat kartu tersebut pada host asal, dalam keadaan VM baru mati:

```bash
qm set 102 --hostpci0 0000:1a:00,pcie=1
```

Sintaks tanpa nomor fungsi meneruskan kedua fungsi kartu. Alamat PCI dapat berbeda pada host lain, jadi jangan menyalin alamat tanpa pemeriksaan.

**Jaringan manajemen host asal memakai `06:00.0` / `enp6s0`; jangan meneruskan kartu tersebut.** Controller SATA bawaan juga melayani disk sistem Proxmox dan tidak boleh dilepas dari host untuk VM ini.

Setelah jaringan atau PCI siap, nyalakan VM lalu periksa interface, IP, rute, dan akses manajemen dari Console sebelum mengandalkannya sebagai router.

## 7. Menyimpan SSD asli dan backup

Image paket ini berdiri sendiri dan tidak memerlukan SSD asli untuk boot. SSD fisik dapat disimpan setelah tidak ada VM yang mengaksesnya. Matikan server sebelum melepas SSD SATA jika dukungan hot-swap belum dipastikan.

Kondisi host saat panduan dibuat:

- **VM 100:** menunjuk SSD fisik dan sudah diperbaiki dengan model `SSD16G`; lisensi Level 6 sudah diverifikasi. VM dimatikan setelah pemeriksaan.
- **VM 101:** memakai overlay image uji dan tetap berjalan; tidak memakai SSD fisik. Overlay ini masih mempunyai backing file raw di `/root/mikrotik-backup/SSD16G-SZHYPO1611140212411.img`.
- **Paket `/root/HCC0-4FJR`:** mandiri; tidak bergantung pada backing file VM 101.

**Jangan hapus atau pindahkan raw backup di `/root/mikrotik-backup` selama VM 101 masih mengandalkannya.** Pemindahan paket ini tidak mengubah disk aktif VM 101.

Simpan salinan folder paket di media lain. Gunakan image untuk pemulihan atau penggantian instalasi, dan jalankan satu instalasi aktif untuk lisensi yang sama.

## Referensi

- [Lisensi RouterOS x86 — MikroTik](https://manual.mikrotik.com/docs/getting-started/routeros-licensing/x86/)
- [Manual VM Proxmox](https://pve.proxmox.com/pve-docs/qm.1.html)
- [PCI passthrough Proxmox](https://pve.proxmox.com/wiki/PCI_Passthrough)

Perintah dapat diperiksa terhadap versi host menggunakan `qm help create`, `qm help set`, `qm help importdisk`, dan `pvesm help status`.
