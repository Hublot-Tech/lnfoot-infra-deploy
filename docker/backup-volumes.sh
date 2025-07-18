#!/bin/bash
backup_dir=~/docker_volume_backups
mkdir -p "$backup_dir"

for vol_path in /var/lib/volumes/*; do
  if [[ -d "$vol_path/_data" ]]; then
    vol_name=$(basename "$vol_path")
    tar czf "$backup_dir/${vol_name}.tar.gz" -C "$vol_path/_data" .
    echo "✅ Backed up $vol_name"
  fi
done

echo "🎉 All volumes backed up to $backup_dir"
