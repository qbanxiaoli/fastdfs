#  fastdfs
使用docker-compose 创建fastdfs单机版服务(tracker,storage,nginx)
## 使用
1. 安装docker和docker-compose  
2. 安装git    
3. clone项目    
 ```
 git clone https://qbanxiaoli@github.com/qbanxiaoli/fastdfs.git 
 ```    
4. 进入fastdfs目录  
```
 cd fastdfs
```   
5. 修改docker-compose.yml
```
version: '3.0'
services:
  fastdfs:
    build: .
    image: qbanxiaoli/fastdfs
    # 该容器是否需要开机启动+自动重启。若需要，则取消注释。
    restart: always
    container_name: fastdfs
    environment:
      # nginx服务端口,默认8080端口，可修改
      - WEB_PORT=8080
      # tracker_server服务端口，默认22122端口，可修改
      - FDFS_PORT=22122
      # docker所在主机的IP地址，默认使用eth0网卡的地址
      - IP=123.207.85.155
    volumes:
      # 将本地目录映射到docker容器内的fastdfs数据存储目录，将fastdfs文件存储到主机上，以免每次重建docker容器，之前存储的文件就丢失了。
      - ${HOME}/fastdfs:/var/local/fdfs
      # 使docker具有root权限以读写主机上的目录
    privileged: true
    # 网络模式为host，即直接使用主机的网络接口
    network_mode: "host"
```  
docker所在主机IP必须修改.
 
6. 执行docker-compose命令  
```
docker-compose up -d
```
7. 测试fastdfs是否搭建成功
```
docker exec -it fastdfs /bin/bash 
```
```
echo "Hello FastDFS!">index.html
```
```
fdfs_test /etc/fdfs/client.conf upload index.html
```      


重启tracker_server
```
/usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf restart
```
重启storage_server
```
/usr/bin/fdfs_storaged /etc/fdfs/storage.conf restart
```
查看storage状态
```
fdfs_monitor /etc/fdfs/client.conf
```
该镜像已经上传到docker hub，也可用如下命令拉取镜像后直接运行容器
```
docker pull qbanxiaoli/fastdfs
```
```
docker run -d --restart=always --privileged=true --net=host --name=fastdfs -e IP=123.207.85.155 -v ${HOME}/fastdfs:/var/local/fdfs qbanxiaoli/fastdfs
```