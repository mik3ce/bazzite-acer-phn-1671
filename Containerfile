#!/bin/bash
set -e

# Rileva la versione del kernel installata nell'immagine Bazzite
KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel)

# Installa le dipendenze di compilazione
dnf install -y make gcc git "kernel-devel-${KERNEL_VERSION}"

# Clona e compila il modulo linuwu_sense
git clone https://github.com/0x7375646F/linuwu_sense.git /tmp/linuwu_sense
cd /tmp/linuwu_sense
make -C "/lib/modules/${KERNEL_VERSION}/build" M=$PWD modules

# Sposta il modulo compilato nell'albero del kernel
mkdir -p "/lib/modules/${KERNEL_VERSION}/extra"
cp linuwu_sense.ko "/lib/modules/${KERNEL_VERSION}/extra/"

# Aggiorna la mappa dei moduli e imposta il caricamento automatico all'avvio
depmod -a "${KERNEL_VERSION}"
mkdir -p /etc/modules-load.d/
echo "linuwu_sense" > /etc/modules-load.d/linuwu_sense.conf

# Pulizia dei file temporanei
rm -rf /tmp/linuwu_sense
dnf clean all