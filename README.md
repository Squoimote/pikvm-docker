# Actual errors
Error on unit kvmd-tc358743.service
```text
v4l2-ctl[x]: Cannot open device /dev/kvmd-video, exiting.
```
Fixed by modifying /boot/config.txt as the one configured in the container.

Eoor on unit kvmd-otg.service
```text
kvmd-otg[x]: Traceback (most recent call last):
kvmd-otg[x]:   File "/usr/bin/kvmd-otg", line 8, in <module>
kvmd-otg[x]:     sys.exit(main())
kvmd-otg[x]:              ^^^^^^
kvmd-otg[x]:   File "/usr/lib/python3.12/site-packages/kvmd/apps/otg/__init__.py", line 348, in main
kvmd-otg[x]:     options.cmd(config)
kvmd-otg[x]:   File "/usr/lib/python3.12/site-packages/kvmd/apps/otg/__init__.py", line 207, in _cmd_start
kvmd-otg[x]:     udc = usb.find_udc(config.otg.udc)
kvmd-otg[x]:           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
kvmd-otg[x]:   File "/usr/lib/python3.12/site-packages/kvmd/usb.py", line 34, in find_udc
kvmd-otg[x]:     raise RuntimeError("Can't find any UDC")
kvmd-otg[x]: RuntimeError: Can't find any UDC
```
Still searching a fix.

Other error on https nginx server, 502
```text
nginx[1278]: 2024/07/27 21:47:55 [crit] 1278#1278: *7 connect() to unix:/run/kvmd/kvmd.sock failed (2: No such file or directory) while connecting to upstream, client: 192.168.1.50, server: , request: "GET / HTTP/2.0", subrequest: "/auth_check", upstream: "http://unix:/run/kvmd/kvmd.sock:/auth/check", host: "192.168.1.52"
```
Still searching a fix. Failed because kvmd.service do not start. Seems to be same error as otg, "RuntimeError: Can't find any UDC".  
https://github.com/pikvm/pikvm/issues/552  
Try to update the raspberry pi eeprom. Please adapt the solution to your pi, do:
```bash
pacman -Sy rpi4-eeprom
rpi-eeprom-update
```
For CM4 (v4mini and v4plus) do this and reboot before running `rpi-eeprom-update`:
```bash
pacman -Sy rpi4-eeprom
cat >> /etc/default/rpi-eeprom-update << 'EOT'

RPI_EEPROM_USE_FLASHROM=1
CM4_ENABLE_RPI_EEPROM_UPDATE=1
EOT
cat >> /boot/config.txt << 'EOT'

[cm4]
dtparam=spi=on
dtoverlay=audremap
dtoverlay=spi-gpio40-45
EOT
```
After this reboot a last time.

# Build
Build on Raspberry Pi. It is ARMv7 architecture, so it can be built on aarch64 (ARMv8).
```bash
git clone https://github.com/Squoimote/pikvm-docker.git
cd pikvm-docker
docker build --platform=linux/arm/v7 -t squoimote/pikvm-docker .
```

# Run
```bash
docker run -d --name=pikvm --hostname=pikvm --net=host -t --security-opt seccomp=unconfined --privileged -v /var/lib/kvmd/pst:/var/lib/kvmd/pst -v /var/lib/kvmd/msd:/var/lib/kvmd/msd -v /var/log/kvmd:/var/log -v /dev:/dev -v /sys:/sys -v /sys/fs/cgroup/pikvm.scope:/sys/fs/cgroup:rw --init=false --cgroupns=host --tmpfs=/tmp --tmpfs=/run squoimote/pikvm-docker:latest
```

# Needed info
Since the official project is complex, the solution is packaged into an Archlinux container. Maybe in the future each component will be segmented into different restricted containers.  
This solution is hardware dependant (need PiKVM items), so modifications of original system may be required.

## Useful links
https://files.pikvm.org/  
https://github.com/pikvm  
https://github.com/pikvm/os/tree/master  

## From builder official project
### Link for builder env informations:  
https://github.com/pikvm/pi-builder/blob/master/stages/arch/os/Dockerfile.part

### USB-C activation (from powering to USB usable):  
https://www.interelectronix.com/raspberry-pi-4-usb-c-host-mode.html  
https://github.com/pikvm/pi-builder/blob/master/stages/common/dwc2-host/Dockerfile.part

### Fix reboot and shutdown issue after configuring USB-C and OTG:  
https://github.com/pikvm/os/tree/master/stages/arch/pikvm-otg-console  

#### On the host or container? Probably the host:  
```bash
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
```

#### And inside the container:
```bash
cat > /etc/kvmd/override.d/0000-vendor-otg-serial.yaml << 'EOT'
# Generated by OS builder. Do not edit this file!
otg:
    devices:
        serial:
            enabled: true
EOT
```
