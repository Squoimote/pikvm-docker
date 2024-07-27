#!/bin/bash

# Leave on first error
set -e

## Workaround marginal trust error on gpg when using pacman (since Feb 2024)
## archlinuxarm gpg keys are SHA1 and it is now deprecated by gpg.
## See: https://archlinuxarm.org/forum/viewtopic.php?t=16762
# Other sources
# https://wiki.archlinux.org/title/Pacman/Package_signing#Resetting_all_the_keys
# https://man.archlinux.org/man/gpg.1.en#allow-weak-key-signatures
# https://man.archlinux.org/man/pacman-key.8
rm -rf /etc/pacman.d/gnupg
pacman-key --init
echo "allow-weak-key-signatures" >> /etc/pacman.d/gnupg/gpg.conf
pacman-key --populate archlinuxarm
pacman --noconfirm -Sy archlinuxarm-keyring

# Setup Repository
echo PIKVM_REPO_KEY=$PIKVM_REPO_KEY

mkdir -p /etc/gnupg
echo standard-resolver >> /etc/gnupg/dirmngr.conf
pacman-key --keyserver hkps://keys.gnupg.net:443 -r $PIKVM_REPO_KEY \
|| pacman-key --keyserver hkps://pgp.mit.edu:443 -r $PIKVM_REPO_KEY \
|| pacman-key --keyserver hkps://keyserver.ubuntu.com:443 -r $PIKVM_REPO_KEY

pacman-key --lsign-key $PIKVM_REPO_KEY
echo -e "\n[pikvm]" >> /etc/pacman.conf
echo "Server = $PIKVM_REPO_URL/$BOARD-$ARCH" >> /etc/pacman.conf
echo "SigLevel = Optional DatabaseOptional TrustAll" >> /etc/pacman.conf

# Upgrade and install Packages
pacman --noconfirm -Syu vim man bash-completion
pacman --noconfirm --ask=4 -S pikvm-os-raspberrypi \
&& (mv /boot/config.txt.pacsave /boot/config.txt || true) \
&& (mv /boot/cmdline.txt.pacsave /boot/cmdline.txt || true)
pacman --noconfirm --ask=4 -S \
	kvmd-platform-$PLATFORM-$BOARD kvmd-webterm kvmd-oled kvmd-fan\
	tesseract tesseract-data-eng\
	wiringpi\
	pastebinit\
	tmate\
	hostapd\
	edid-decode\
&& if [[ $PLATFORM =~ ^v4.*$ ]]; then pacman --noconfirm --ask=4 -S flashrom-pikvm; fi
pacman --noconfirm -Scc

echo "LABEL=PIPST  /var/lib/kvmd/pst  ext4  nodev,nosuid,noexec,ro,errors=remount-ro,X-kvmd.pst-user=kvmd-pst  0 2" >> /etc/fstab

# Enable PiKVM Units Service
systemctl enable kvmd-bootconfig \
&& systemctl enable kvmd kvmd-pst kvmd-nginx kvmd-webterm \
&& if [[ $PLATFORM =~ ^.*-hdmi$ ]]; then systemctl enable kvmd-tc358743; fi \
&& if [[ $PLATFORM =~ ^v0.*$ ]]; then systemctl mask serial-getty@ttyAMA0.service; fi \
&& if [[ $PLATFORM =~ ^v[234].*$ ]]; then \
	systemctl enable kvmd-otg
	echo "LABEL=PIMSD  /var/lib/kvmd/msd  ext4  nodev,nosuid,noexec,ro,errors=remount-ro,X-kvmd.otgmsd-user=kvmd  0 2" >> /etc/fstab
fi \
&& if [[ $BOARD =~ ^rpi4|zero2w$ && $PLATFORM =~ ^v[234].*-hdmi$ ]]; then systemctl enable kvmd-janus; fi \
&& if [[ $BOARD =~ ^rpi3$ && $PLATFORM =~ ^v[1].*-hdmi$ ]]; then systemctl enable kvmd-janus; fi \
&& if [[ $PLATFORM =~ ^v[34].*$ ]]; then systemctl enable kvmd-watchdog; fi \
&& if [[ -n "$OLED" || $PLATFORM =~ ^v4.*$ ]]; then systemctl enable kvmd-oled kvmd-oled-reboot kvmd-oled-shutdown; fi \
&& if [[ -n "$FAN" || $PLATFORM == v4plus-hdmi ]]; then systemctl enable kvmd-fan; fi

# Create motd
cat > /etc/motd << 'EOT'
	 _____ _  _  ____      ____  __       ___     ___    ___  _  __ ____  ____
	|  __ (_)| |/ /\ \    / /  \/  |     |  _ \  / _ \  / __|| |/ /|  __||  _ \
	| |__) | | ' /  \ \  / /| \  / | ___ | | | \| | | || |   | ' / | |__ | |_) |
	|  ___/ ||  <    \ \/ / | |\/| ||___|| | | || | | || |   |  <  |  __|| .  /
	| |   | || . \    \  /  | |  | |     | |_| /| |_| || |__ | . \ | |__ | |\ \
	|_|   |_||_|\_\    \/   |_|  |_|     |___ /  \___/  \___||_|\_\|____||_| \_\

    Welcome to PiKVM - The Open Source KVM over IP on Raspberry Pi
    ____________________________________________________________________________

    The root filesystem of PiKVM is mounted in the read-only mode by default.
    Use command "rw" to remount it in the RW-mode and "ro" to switch it back.
    If the filesystem is busy and doesn't switch to the RO-mode, use "reboot"
    to reboot the device, don't leave it in the RW-mode.

    Useful commands:
      * Preventing kernel messages in the console:  dmesg -n 1
      * Changing the Web UI password:  kvmd-htpasswd set admin
      * Changing the root password:    passwd

    Links:
      * Official website:  https://pikvm.org
      * Documentation:     https://docs.pikvm.org
      * Auth & 2FA:        https://docs.pikvm.org/auth
      * Networking:        https://wiki.archlinux.org/title/systemd-networkd
	  * Docker project:    https://github.com/Squoimote/pikvm-docker/tree/main
EOT

sed -i -f /usr/share/kvmd/configs.default/os/cmdline/$PLATFORM-$BOARD.sed /boot/cmdline.txt \
&& cp /usr/share/kvmd/configs.default/os/boot-config/$PLATFORM-$BOARD.txt /boot/config.txt

# I dunno what it is. I think it is useless because it is absent from official project script
# sed -i -e "s/-session   optional   pam_systemd.so/#-session   optional   pam_systemd.so/g" /etc/pam.d/system-login

# Fix the error when processing refuse to stop when OTG activated, trying to run the service on container (experimental).
systemctl enable getty@ttyGS0.service
echo ttyGS0 >> /etc/securetty
mkdir /etc/systemd/system/getty@ttyGS0.service.d
cat > /etc/systemd/system/getty@ttyGS0.service.d/override.conf << 'EOT'
# https://github.com/raspberrypi/linux/issues/1929
[Service]
TTYReset=no
TTYVHangup=no
TTYVTDisallocate=no
EOT
cat > /etc/kvmd/override.d/0000-vendor-otg-serial.yaml << 'EOT'
# Generated by OS builder. Do not edit this file!
otg:
    devices:
        serial:
            enabled: true
EOT

# Setting passwords
echo "$WEBUI_ADMIN_PASSWD" | kvmd-htpasswd set --read-stdin admin
sed -i "\$d" /etc/kvmd/ipmipasswd \
&& echo "admin:$IPMI_ADMIN_PASSWD -> admin:$WEBUI_ADMIN_PASSWD" >> /etc/kvmd/ipmipasswd

# Prepare software
kvmd-gencert --do-the-thing \
&& kvmd-gencert --do-the-thing --vnc