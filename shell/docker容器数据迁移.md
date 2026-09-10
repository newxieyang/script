##### 1、停止 docker 服务
```
systemctl stop docker
systemctl stop docker.socket
```

##### 2、复制全部 docker 数据到 /data
```
mkdir -p /data/docker
rsync -av /var/lib/docker/ /data/docker/
```

##### 3、修改 docker 配置，指定新的数据根目录
vim /etc/docker/daemon.json
```
{
  "data-root": "/data/docker"
}
```
##### 4、重载配置，启动 docker
```
systemctl daemon-reload
systemctl start docker
```

##### 5、验证生效

```
docker info | grep "Docker Root Dir"
```

