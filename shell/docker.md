##### 1 安装必要的软件

```
apt-get update

apt-get install -y  curl build-essential cmake ninja-build pkg-config gcc-9 g++-9 ccache
	
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 90
```

##### 2. 进入容器

```
docker run -it  --name ubuntu20-arm64-dev --platform linux/arm64   ubuntu20-arm64-qemu /bin/bash
docker exec -it 4e6d43ff1b0b /bin/bash 

```


##### 3. 把容器保存成镜像
```
docker commit 16cbdc7fbfb8 ubuntu20-arm64-build:latest

```


#### wsl-- ARMLinx 不能运行arm docker 容器的时候
```
ls -l /proc/sys/fs/binfmt_misc/register
mount | grep binfmt_misc
printf '%s\n' ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:OCF' > /proc/sys/fs/binfmt_misc/register
mount | grep binfmt_misc
```