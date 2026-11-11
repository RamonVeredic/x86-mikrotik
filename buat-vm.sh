#!/usr/bin/env bash
set -euo pipefail
vm_id=${1:?Pemakaian: bash buat-vm.sh VM_ID_BARU [STORAGE]}
storage_name=${2:-local-lvm}
[[ "$vm_id" =~ ^[1-9][0-9]{2,8}$ ]] || { echo 'VM ID harus angka 100 atau lebih.' >&2; exit 1; }
image_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image_file="$image_dir/HCC0-4FJR.qcow2"
[[ -f "$image_file" ]] || { echo 'Image HCC0-4FJR.qcow2 tidak ditemukan.' >&2; exit 1; }
if qm config "$vm_id" >/dev/null 2>&1; then
  echo "VM $vm_id sudah ada; tidak diubah." >&2
  exit 1
fi
pvesm status --storage "$storage_name"
qm create "$vm_id" --name mikrotik-HCC0-4FJR --memory 1024 --cores 2 --machine q35 --bios seabios --onboot 0
qm importdisk "$vm_id" "$image_file" "$storage_name"
disk_volume=$(qm config "$vm_id" | sed -n 's/^unused0: //p')
[[ -n "$disk_volume" && "$disk_volume" != *,* ]] || { echo 'Periksa hasil impor disk sebelum melanjutkan.' >&2; exit 1; }
qm set "$vm_id" --sata0 "$disk_volume,serial=SZHYPO1611140212411,ssd=1" --boot order=sata0 --args '-set device.sata0.model=SSD16G'
echo "VM $vm_id siap. Belum dinyalakan dan belum dipasang jaringan atau PCI."
echo 'Setelah boot, cek /system license print: Software ID HCC0-4FJR, nlevel 6.'
