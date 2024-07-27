FROM --platform=linux/arm/v7 menci/archlinuxarm:base
ENV container=docker  
 
ENV PIKVM_REPO_KEY=912C773ABBD1B584
ENV PIKVM_REPO_URL=https://files.pikvm.org/repos/arch
# ENV BOARD=rpi2
# ENV BOARD=rpi3
ENV BOARD=rpi4
ENV ARCH=arm
ENV WEBUI_ADMIN_PASSWD="pikvm-docker"
ENV IPMI_ADMIN_PASSWD="pikvm-docker"
# ENV PLATFORM=v2-hdmiusb
# ENV PLATFORM=v3-hdmiusb
# ENV PLATFORM=v4-hdmi
# ENV PLATFORM=v4mini-hdmi
ENV PLATFORM=v4plus-hdmi

COPY install-pikvm.sh /root/install-pikvm.sh

RUN /root/install-pikvm.sh

ENTRYPOINT ["/lib/systemd/systemd"]

CMD ["--log-level=info", "--system"]
STOPSIGNAL SIGRTMIN+3

# COPY container.target /etc/systemd/system/container.target
 
# RUN ln -sf /etc/systemd/system/container.target /etc/systemd/system/default.target \
# && mkdir /etc/systemd/system/container.target.wants/

# COPY *.service /etc/systemd/system/

# RUN ln -sf /etc/systemd/system/kvmd-nginx.service /etc/systemd/system/container.target.wants/kvmd-nginx.service \
# && ln -sf /etc/systemd/system/kvmd-otg.service /etc/systemd/system/container.target.wants/kvmd-otg.service \
# &&  ln -sf /etc/systemd/system/kvmd.service /etc/systemd/system/container.target.wants/kvmd.service \
# && ln -sf /etc/systemd/system/kvmd-webterm.service /etc/systemd/system/container.target.wants/kvmd-webterm.service \
# && find /lib/systemd/system/ -name '*.target' ! -name 'sysinit.target' -type f -exec rm -f {} + \
