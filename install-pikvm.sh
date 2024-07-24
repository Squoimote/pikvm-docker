#!/bin/bash

## Workaround marginal trust error on gpg when using pacman (since Feb 2024)
## archlinuxarm gpg keys are SHA1 and it is now deprecated by gpg.
## See: https://archlinuxarm.org/forum/viewtopic.php?t=16762
# Other sources
# https://wiki.archlinux.org/title/Pacman/Package_signing#Resetting_all_the_keys
# https://man.archlinux.org/man/gpg.1.en#allow-weak-key-signatures
# https://man.archlinux.org/man/pacman-key.8
rm -rf /etc/pacman.d/gnupg
pacman-key --noconfirm --init
echo "allow-weak-key-signatures" >> /etc/pacman.d/gnupg/gpg.conf
pacman-key --noconfirm --populate archlinuxarm

# Setup Repo 

echo PIKVM_REPO_KEY=$PIKVM_REPO_KEY

mkdir -p /etc/gnupg
echo standard-resolver >> /etc/gnupg/dirmngr.conf
pacman-key --init
pacman-key --keyserver hkps://keyserver.ubuntu.com:443 -r $PIKVM_REPO_KEY \
	|| pacman-key --keyserver hkps://keys.gnupg.net:443 -r $PIKVM_REPO_KEY \
	|| pacman-key --keyserver hkps://pgp.mit.edu:443 -r $PIKVM_REPO_KEY \

pacman-key --lsign-key $PIKVM_REPO_KEY
echo -e "\n[pikvm]" >> /etc/pacman.conf
echo "Server = $PIKVM_REPO_URL/$BOARD-$ARCH" >> /etc/pacman.conf
echo "SigLevel = Optional DatabaseOptional TrustAll" >> /etc/pacman.conf


# Install Packages
pacman --noconfirm --ask=4 -Syu \
	kvmd-platform-$PLATFORM-$BOARD \
	kvmd-webterm \
	kvmd-oled \
	kvmd-fan \
	wiringpi \
	pastebinit \
	tmate \
	netctl \
	parted \
	e2fsprogs \
	dos2unix \
	man
pacman --noconfirm -Scc

# Enable Services
systemctl enable kvmd \
	&& systemctl enable kvmd-nginx \
	&& systemctl enable kvmd-webterm \
	&& ([[ ! $PLATFORM =~ ^.*-hdmi$ ]] || systemctl enable kvmd-tc358743) \
	&& ([[ ! $PLATFORM =~ ^v[01]-.*$ ]] || systemctl mask serial-getty@ttyAMA0.service) \
	&& ([[ ! $PLATFORM =~ ^v[23]-.*$ ]] || ( \
		systemctl enable kvmd-otg \
		&& echo "/dev/mmcblk0p3 /var/lib/kvmd/msd  ext4  nodev,nosuid,noexec,ro,errors=remount-ro,data=journal,X-kvmd.otgmsd-root=/var/lib/kvmd/msd,X-kvmd.otgmsd-user=kvmd  0 0" >> /etc/fstab \
	)) \
	&& ([[ $BOARD == rpi4 && $PLATFORM =~ ^v[23]-hdmi$ ]] && systemctl enable kvmd-janus || true)

sed -i -e "s/-session   optional   pam_systemd.so/#-session   optional   pam_systemd.so/g" /etc/pam.d/system-login

echo "$WEBUI_ADMIN_PASSWD" | kvmd-htpasswd set --read-stdin admin

sed -i "\$d" /etc/kvmd/ipmipasswd \
	&& echo "admin:$IPMI_ADMIN_PASSWD -> admin:$WEBUI_ADMIN_PASSWD" >> /etc/kvmd/ipmipasswd

kvmd-gencert --do-the-thing \
	&& kvmd-gencert --do-the-thing --vnc
