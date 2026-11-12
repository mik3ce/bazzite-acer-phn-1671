# bazzite-acer-phn-1671

Custom [Bazzite](https://bazzite.gg) image for the **Acer Predator Helios Neo 16
(PHN16-71)**. It is the stock Bazzite **GNOME / NVIDIA open** image plus the
[`linuwu_sense`](https://github.com/0x7375646F/Linuwu-Sense) kernel module
(fan control, keyboard RGB, battery limiter, thermal profiles, ...).

| | |
|---|---|
| Base image | `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable` |
| Built image | `ghcr.io/mik3ce/bazzite-acer-phn-1671:latest` |
| Builder | [BlueBuild](https://blue-build.org) |

## Installation

> [!WARNING]
> The image is currently **unsigned** and contains an unsigned out-of-tree
> kernel module. Read [Secure Boot](#secure-boot) before using it.

Rebase an existing Fedora Atomic / Bazzite installation:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/mik3ce/bazzite-acer-phn-1671:latest
systemctl reboot
```

To go back to stock Bazzite:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable
systemctl reboot
```

## Usage

Check that the module loaded:

```bash
lsmod | grep linuwu_sense
dmesg | grep -i linuwu
```

The controls live under
`/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/`.

Fan speed (CPU, GPU; `0` = auto, `100` = maximum):

```bash
echo 50,70 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/fan_speed
```

Thermal profile:

```bash
cat /sys/firmware/acpi/platform_profile_choices
echo performance | sudo tee /sys/firmware/acpi/platform_profile
```

Battery limiter (80%):

```bash
echo 1 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/battery_limiter
```

### Non-root access

The image creates a `linuwu_sense` group and a boot service that makes the
sysfs controls writable by that group. Add yourself once, then log out and back
in:

```bash
sudo usermod -aG linuwu_sense "$USER"
```

Do **not** run upstream's `make install`: it would set up DKMS and install a
second copy of the module. The module is already built into this image. The
upstream Python GUI and third-party frontends still work on top of it:
<https://github.com/0x7375646F/Linuwu-Sense#gui>.

## Updating

`rpm-ostree upgrade` pulls the newest build of this image. Because the module
is compiled against the kernel of that same image, the two always match. The
GitHub Actions workflow rebuilds weekly so there is usually a fresh image ready
when Bazzite ships a new kernel.

## Notes and caveats

### Secure Boot

The module is built from source during the image build and is **not signed**.
With Secure Boot enabled the kernel refuses to load it. Either disable Secure
Boot or sign the module with a MOK key (see upstream's
`module_signing_readme` and `dkms-sign.sh`).

### Signing

The workflow builds with `--no-sign` so it works without extra secrets. To sign
the image:

1. Generate a cosign key pair and commit `cosign.pub` to this repository.
2. Add the private key as the `SIGNING_SECRET` Actions secret.
3. Add `cosign_private_key: ${{ secrets.SIGNING_SECRET }}` to the action inputs
   and remove `build_opts: "--no-sign"`.
4. Add `- type: signing` to the end of `config/recipe.yml`.

See <https://blue-build.org/how-to/cosign/>.

### Kernel module provenance

`linuwu_sense` is an unofficial, reverse-engineered driver. Use it at your own
risk. The module is fetched from the upstream `main` branch at build time; pin a
commit in `files/scripts/build-linuwu-sense.sh` if you want reproducible builds.

## Repository layout

```text
.
├── .github/workflows/build.yml          # GitHub Actions (BlueBuild, weekly)
├── config/recipe.yml                    # image definition
├── files/
│   ├── scripts/build-linuwu-sense.sh    # compiles + installs the module
│   └── system/
│       └── usr/lib/...                  # modprobe, modules-load, systemd units
└── README.md
```

## Local build

```bash
bluebuild build ./config/recipe.yml
```

Requires the [BlueBuild CLI](https://blue-build.org/how-to/local/).
