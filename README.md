# FastDFS+FastDHT(单机+集群版)
使用docker-compose创建FastDFS+FastDHT(单机+集群版)服务(tracker,storage,fastdht,nginx)
## 搭建教程
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
5. 修改docker-compose.yml，指定IP(多个IP集群用逗号分割)

6. 执行docker-compose命令，linux环境下需要指定使用docker-compose-linux.yml文件
```
 docker-compose up -d 或者 docker-compose -f docker-compose-linux.yml up -d
```
7. 至此fastdfs文件系统已经搭建完成，下面测试是否成功
```
 docker exec -it fastdfs /bin/bash 

 echo "Hello FastDFS!">index.html

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
 重启fastdht_server
```
 /usr/local/bin/fdhtd /etc/fdht/fdhtd.conf restart
```
 重启nginx
```
 /usr/local/nginx/sbin/nginx -t
 /usr/local/nginx/sbin/nginx -s reload
```
 查看storage状态
```
 fdfs_monitor /etc/fdfs/client.conf
```
 该镜像已经上传到公开镜像仓库，也可跳过镜像构建步骤，直接从Docker Hub或者阿里云容器镜像仓库上拉取，linux环境下可用如下命令拉取镜像后直接运行容器
```
 docker pull qbanxiaoli/fastdfs 或者 docker pull registry.cn-hangzhou.aliyuncs.com/qbanxiaoli/fastdfs

 docker run -d --restart=always --net=host --name=fastdfs -e IP=192.168.0.105 -v ～/fastdfs:/var/local qbanxiaoli/fastdfs
```