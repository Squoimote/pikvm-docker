# Run

```Bash
docker run -d --name=pikvm --hostname=pikvm --net=host -t --security-opt seccomp=unconfined --privileged -v /var/lib/kvmd/pst:/var/lib/kvmd/pst -v /var/lib/kvmd/msd:/var/lib/kvmd/msd -v /var/log/kvmd:/var/log -v /dev:/dev -v /sys:/sys -v /sys/fs/cgroup/pikvm.scope:/sys/fs/cgroup:rw --init=false --cgroupns=host --tmpfs=/tmp --tmpfs=/run squoimote/pikvm-docker:latest
```
