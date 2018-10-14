# 使用超小的Linux镜像alpine
FROM alpine

ENV HOME /root

# 安装准备
RUN    apk update \
        && apk add --no-cache --virtual .build-deps bash gcc libc-dev make openssl-dev pcre-dev zlib-dev linux-headers curl gnupg libxslt-dev gd-dev geoip-dev git wget

# 复制工具
#ADD soft ${HOME}

# 下载libfastcommon、fastdfs、fastdfs-nginx-module、fastdht、berkeley-db、nginx插件的源码
RUN     cd ${HOME} \
        && curl -fSL https://github.com/happyfish100/libfastcommon/archive/master.tar.gz -o libfastcommon-master.tar.gz \
        && curl -fSL https://github.com/happyfish100/fastdfs/archive/master.tar.gz -o fastdfs-master.tar.gz \
        && curl -fSL https://github.com/happyfish100/fastdfs-nginx-module/archive/master.tar.gz -o fastdfs-nginx-module-master.tar.gz \
        && curl -fSL https://github.com/happyfish100/fastdht/archive/master.tar.gz -o fastdht-master.tar.gz \
        && curl -fSL http://nginx.org/download/nginx-1.15.3.tar.gz -o nginx-1.15.3.tar.gz \
        && wget --http-user=username --http-passwd=password "http://download.oracle.com/otn/berkeley-db/db-18.1.25.tar.gz" \
        && tar xvf libfastcommon-master.tar.gz \
        && tar xvf fastdfs-master.tar.gz \
        && tar xvf fastdfs-nginx-module-master.tar.gz \
        && tar xvf fastdht-master.tar.gz \
        && tar xvf nginx-1.15.3.tar.gz \
        && tar xvf db-18.1.25.tar.gz

# 安装libfastcommon
RUN     cd ${HOME}/libfastcommon-master/ \
        && ./make.sh \
        && ./make.sh install

# 安装fastdfs
RUN     cd ${HOME}/fastdfs-master/ \
        && ./make.sh \
        && ./make.sh install

#安装berkeley db
WORKDIR ${HOME}/db-18.1.25/build_unix
RUN     ../dist/configure --prefix=/usr/local/db-18.1.25 \
        && make \
        && make install

#安装fastdht
RUN     cd ${HOME}/fastdht-master/ \
        && sed -i "s?CFLAGS='-Wall -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE'?CFLAGS='-Wall -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -I/usr/local/db-18.1.25/include/ -L/usr/local/db-18.1.25/lib/'?" make.sh \
        && ./make.sh \
        && ./make.sh install \
        && cp /usr/local/db-18.1.25/lib/libdb-18.1.so /usr/lib

# 配置fastdfs: base_dir
RUN     cd /etc/fdfs/ \
        && cp storage.conf.sample storage.conf \
        && cp tracker.conf.sample tracker.conf \
        && cp client.conf.sample client.conf \
        && sed -i "s|/home/yuqing/fastdfs|/var/local/fdfs/tracker|g" /etc/fdfs/tracker.conf \
        && sed -i "s|/home/yuqing/fastdfs|/var/local/fdfs/storage|g" /etc/fdfs/storage.conf \
        && sed -i "s|/home/yuqing/fastdfs|/var/local/fdfs/storage|g" /etc/fdfs/client.conf

# 获取nginx源码，与fastdfs插件一起编译
RUN     cd ${HOME} \
        && chmod u+x ${HOME}/fastdfs-nginx-module-master/src/config \
        && cd nginx-1.15.3 \
        && ./configure --add-module=${HOME}/fastdfs-nginx-module-master/src \
        && make && make install

# 设置nginx和fastdfs联合环境，并配置nginx
RUN     cp ${HOME}/fastdfs-nginx-module-master/src/mod_fastdfs.conf /etc/fdfs/ \
        && sed -i "s|^store_path0.*$|store_path0=/var/local/fdfs/storage|g" /etc/fdfs/mod_fastdfs.conf \
        && sed -i "s|^url_have_group_name =.*$|url_have_group_name = true|g" /etc/fdfs/mod_fastdfs.conf \
        && cd ${HOME}/fastdfs-master/conf/ \
        && cp http.conf mime.types anti-steal.jpg /etc/fdfs/ \
        && echo -e "\
           events {\n\
           worker_connections  1024;\n\
           }\n\
           http {\n\
           include       mime.types;\n\
           default_type  application/octet-stream;\n\
           server {\n\
               listen 8080;\n\
               server_name localhost;\n\
               location ~ /group[0-9]/M00 {\n\
                 ngx_fastdfs_module;\n\
               }\n\
             }\n\
            }" >/usr/local/nginx/conf/nginx.conf

# 清理文件
RUN rm -rf ${HOME}/*
RUN apk del .build-deps gcc libc-dev make openssl-dev linux-headers curl gnupg libxslt-dev gd-dev geoip-dev
RUN apk add bash pcre-dev zlib-dev


# 配置启动脚本，在启动时中根据环境变量替换nginx端口、fastdfs端口
# 默认nginx端口
ENV WEB_PORT 8080
# 默认fastdfs端口
ENV FDFS_PORT 22122
# 创建启动脚本
RUN echo -e "\
ln -s /usr/lib/libssl.so.45 /usr/lib/libssl.so.1.0.0; \n\
ln -s /usr/lib/libcrypto.so.43 /usr/lib/libcrypto.so.1.0.0; \n\
mkdir -p /var/local/fdfs/storage/data /var/local/fdfs/tracker; \n\
ln -s /var/local/fdfs/storage/data/ /var/local/fdfs/storage/data/M00; \n\n\
sed -i \"s/listen\ .*$/listen\ \$WEB_PORT;/g\" /usr/local/nginx/conf/nginx.conf; \n\
sed -i \"s/http.server_port=.*$/http.server_port=\$WEB_PORT/g\" /etc/fdfs/storage.conf; \n\n\
if [ \"\$IP\" = \"\" ]; then \n\
    IP=`ifconfig eth0 | grep inet | awk '{print \$2}'| awk -F: '{print \$2}'`; \n\
fi \n\
sed -i \"s/^tracker_server=.*$/tracker_server=\$IP:\$FDFS_PORT/g\" /etc/fdfs/client.conf; \n\
sed -i \"s/^tracker_server=.*$/tracker_server=\$IP:\$FDFS_PORT/g\" /etc/fdfs/storage.conf; \n\
sed -i \"s/^tracker_server=.*$/tracker_server=\$IP:\$FDFS_PORT/g\" /etc/fdfs/mod_fastdfs.conf; \n\n\
/etc/init.d/fdfs_trackerd start; \n\
/etc/init.d/fdfs_storaged start; \n\
/usr/local/nginx/sbin/nginx; \n\
tail -f /usr/local/nginx/logs/access.log \
">/start.sh \
&& chmod u+x /start.sh

ENTRYPOINT ["/bin/bash","/start.sh"]