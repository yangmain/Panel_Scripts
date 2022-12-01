#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

year=$(date +%Y)
LOGO="+----------------------------------------------------\n| 耗子Linux面板安装脚本\n+----------------------------------------------------\n| Copyright © 2022-"$year" 耗子 All rights reserved.\n+----------------------------------------------------"
HR="+----------------------------------------------------"

Prepare_system() {
	if [ $(whoami) != "root" ]; then
		echo -e $HR
		echo "错误：请使用root用户运行安装命令。"
		exit 1
	fi

	osCheck=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\.?.*/\1/')
	if [ "${osCheck}" != "8" ] && [ "${osCheck}" != "9" ]; then
		echo -e $HR
		echo "错误：该系统不支持安装耗子Linux面板，请更换RHEL8/9系安装。"
		exit 1
	fi

	is64bit=$(getconf LONG_BIT)
	if [ "${is64bit}" != '64' ]; then
		echo -e $HR
		echo "错误：32位系统不支持安装耗子Linux面板，请更换64位系统安装。"
		exit 1
	fi

	download_Url="https://dl.panel.haozi.xyz"                             # 下载节点
	setup_Path="/www"                                                     # 面板安装目录
	php_Path="${setup_Path}/server/php/panel"                             # 面板PHP目录
	nginx_Path="${setup_Path}/server/nginx"                               # 面板Nginx目录
	php_Version="8.1.13"                                                  # 面板PHP版本
	nginx_Version="1.21.4.1"                                              # 面板Nginx版本
	openssl_Version="1.1.1s"                                              # Nginx的openssl版本
	sshPort=$(cat /etc/ssh/sshd_config | grep 'Port ' | awk '{print $2}') # 系统的SSH端口（部分服务器可能不是22）
	cpuCore=$(cat /proc/cpuinfo | grep "processor" | wc -l)               # CPU核心数

	# 如果核心数不合法，设置为1
	if [ -z "${cpuCore}" ]; then
		cpuCore="1"
	fi

	# 检查www用户是否存在
	wwwUserCheck=$(cat /etc/passwd | grep www)
	if [ "${wwwUserCheck}" == "" ]; then
		# 不存在则创建www用户
		groupadd www
		useradd -s /sbin/nologin -g www www
	fi

	# 设置默认时区
	rm -rf /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

	# 关闭selinux
	[ -s /etc/selinux/config ] && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0 >/dev/null 2>&1

	# 解除文件打开限制
	ulimit -n 204800
	echo 6553560 >/proc/sys/fs/file-max
	checkSoftNofile=$(cat /etc/security/limits.conf | grep '^* soft nofile .*$')
	checkHardNofile=$(cat /etc/security/limits.conf | grep '^* hard nofile .*$')
	checkSoftNproc=$(cat /etc/security/limits.conf | grep '^* soft nproc .*$')
	checkHardNproc=$(cat /etc/security/limits.conf | grep '^* hard nproc .*$')
	checkFsFileMax=$(cat /etc/sysctl.conf | grep '^fs.file-max.*$')
	if [ "${checkSoftNofile}" == "" ]; then
		echo "* soft nofile 204800" >>/etc/security/limits.conf
	fi
	if [ "${checkHardNofile}" == "" ]; then
		echo "* hard nofile 204800" >>/etc/security/limits.conf
	fi
	if [ "${checkSoftNproc}" == "" ]; then
		echo "* soft nproc 204800" >>/etc/security/limits.conf
	fi
	if [ "${checkHardNproc}" == "" ]; then
		echo "* hard nproc 204800 " >>/etc/security/limits.conf
	fi
	if [ "${checkFsFileMax}" == "" ]; then
		echo fs.file-max = 6553560 >>/etc/sysctl.conf
	fi

	# 安装依赖
	dnf install epel-release -y
	dnf config-manager --set-enabled PowerTools
	dnf config-manager --set-enabled powertools
	dnf config-manager --set-enabled CRB
	dnf config-manager --set-enabled Crb
	dnf config-manager --set-enabled crb
	/usr/bin/crb enable
	for lib in gcc gcc-c++ make gd gd-devel git-core perl oniguruma oniguruma-devel libsodium libsodium-devel doxygen firewalld libtool libcurl libcurl-devel flex bison yajl yajl-devel curl-devel libtermcap-devel libevent-devel libuuid-devel lksctp-tools-devel brotli-devel redhat-rpm-config curl bzip2 tar libvpx-devel libzip-devel autoconf wget zip unzip libxml2 libxml2-devel libxslt* zlib zlib-devel libjpeg-devel libpng-devel libwebp-devel freetype freetype-devel lsof pcre pcre-devel crontabs icu libicu libicu-devel openssl openssl-devel c-ares libffi-devel bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel libpcap-devel xz-devel; do
		dnf install ${lib} -y
	done

	# 下载根证书
	mkdir -p /etc/pki/tls/certs
	wget -T 20 -O /etc/pki/tls/certs/ca-bundle.crt https://curl.se/ca/cacert.pem
	if [ "$?" != "0" ]; then
		echo -e $HR
		echo "错误：SSL根证书下载失败，请检查网络是否正常。"
		exit 1
	fi
	chmod 444 /etc/pki/tls/certs/ca-bundle.crt
}

Auto_Swap() {
	# 判断是否有swap
	swap=$(free | grep Swap | awk '{print $2}')
	if [ "${swap}" -gt 1 ]; then
		return
	fi

	# 判断/www是否存在
	if [ ! -d /www ]; then
		mkdir /www
	fi

	# 设置swap
	swapFile="/www/swap"
	dd if=/dev/zero of=$swapFile bs=1M count=2048
	chmod 600 $swapFile
	mkswap -f $swapFile
	swapon $swapFile
	echo "$swapFile    swap    swap    defaults    0 0" >>/etc/fstab
}

Download_Php() {
	# 准备安装目录
	mkdir -p ${php_Path}
	rm -rf ${php_Path}/src
	cd ${php_Path}

	# 下载源码
	wget -T 180 -O ${php_Path}/php-${php_Version}.tar.gz ${download_Url}/php/php-${php_Version}.tar.gz
	if [ "$?" != "0" ]; then
		echo -e $HR
		echo "错误：面板PHP下载失败，请检查网络是否正常。"
		exit 1
	fi

	tar -xvf php-${php_Version}.tar.gz
	rm -f php-${php_Version}.tar.gz
	mv php-${php_Version} src
}

Install_Php() {
	# 进入源码目录
	cd ${php_Path}/src

	# 设置环境变量
	export CFLAGS="-I/usr/local/openssl/include -I/usr/local/curl/include"
	export LIBS="-L/usr/local/openssl/lib -L/usr/local/curl/lib"

	# 开始配置
	./configure --prefix=${php_Path} --with-config-file-path=${php_Path}/etc --enable-fpm --with-fpm-user=www --with-fpm-group=www --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-freetype --with-jpeg --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --with-gettext --enable-fileinfo --enable-opcache --with-sodium --with-webp

	# 编译安装
	make -j${cpuCore}
	make install
	if [ ! -f "${php_Path}/bin/php" ]; then
		echo -e $HR
		echo '错误：面板PHP安装失败，请截图错误信息寻求帮助！'
		rm -rf ${php_Path}
		exit 1
	fi

	# 创建php配置
	mkdir -p ${php_Path}/etc
	\cp php.ini-production ${php_Path}/etc/php.ini

	# 安装zip拓展
	cd ${php_Path}/src/ext/zip
	${php_Path}/bin/phpize
	./configure --with-php-config=${php_Path}/bin/php-config
	make -j${cpuCore}
	make install
	if [ "$?" != "0" ]; then
		echo -e $HR
		echo "错误：面板PHP zip拓展安装失败，请截图错误信息寻求帮助。"
		exit 1
	fi
	cd ../../

	# 写入拓展标记位
	echo ";下方标记位禁止删除，否则将导致PHP拓展无法正常安装！" >>${php_Path}/etc/php.ini
	echo ";haozi" >>${php_Path}/etc/php.ini
	# 写入zip拓展到php配置
	extFile="${php_Path}/lib/php/extensions/no-debug-non-zts-20210902/zip.so"
	if [ -f "${extFile}" ]; then
		echo "extension=zip" >>${php_Path}/etc/php.ini
	fi
	# 写入opcache拓展到php配置
	sed -i '/;haozi/a\zend_extension=opcache\nopcache.enable = 1\nopcache.enable_cli=1\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=32\nopcache.max_accelerated_files=100000\nopcache.revalidate_freq=3\nopcache.save_comments=0\nopcache.jit_buffer_size=128m\nopcache.jit=1205' ${php_Path}/etc/php.ini

	# 设置软链接
	rm -f /usr/bin/php*
	rm -f /usr/bin/pear-panel
	rm -f /usr/bin/pecl-panel
	ln -sf ${php_Path}/bin/php /usr/bin/php-panel
	ln -sf ${php_Path}/bin/phpize /usr/bin/phpize-panel
	ln -sf ${php_Path}/bin/pear /usr/bin/pear-panel
	ln -sf ${php_Path}/bin/pecl /usr/bin/pecl-panel
	ln -sf ${php_Path}/sbin/php-fpm /usr/bin/php-fpm-panel

	# 设置fpm
	cat >${php_Path}/etc/php-fpm.conf <<EOF
[global]
pid = ${php_Path}/var/run/php-fpm.pid
error_log = ${php_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi-panel.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = root
listen.group = root
listen.mode = 0666
user = root
group = root
pm = ondemand
pm.status_path = /phpfpm_panel_status
pm.max_children = 30
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 3
request_terminate_timeout = 0
rlimit_files = 51200
slowlog = var/log/slow.log
EOF
	# 设置PHP进程数
	sed -i "s#pm.max_children.*#pm.max_children = 40#" ${php_Path}/etc/php-fpm.conf
	sed -i "s#pm.start_servers.*#pm.start_servers = 2#" ${php_Path}/etc/php-fpm.conf
	sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 2#" ${php_Path}/etc/php-fpm.conf
	sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 40#" ${php_Path}/etc/php-fpm.conf
	sed -i "s#listen.backlog.*#listen.backlog = 8192#" ${php_Path}/etc/php-fpm.conf
	# 最大上传限制2G
	sed -i 's/post_max_size =.*/post_max_size = 2G/g' ${php_Path}/etc/php.ini
	sed -i 's/upload_max_filesize =.*/upload_max_filesize = 2G/g' ${php_Path}/etc/php.ini
	# 时区PRC
	sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${php_Path}/etc/php.ini
	# sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${php_Path}/etc/php.ini
	sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=1/g' ${php_Path}/etc/php.ini
	# 最大运行时间
	sed -i 's/max_execution_time =.*/max_execution_time = 86400/g' ${php_Path}/etc/php.ini
	sed -i 's/;sendmail_path =.*/sendmail_path = \/usr\/sbin\/sendmail -t -i/g' ${php_Path}/etc/php.ini
	# 禁用函数，需要进一步完善
	sed -i 's/disable_functions =.*/disable_functions = apache_setenv/g' ${php_Path}/etc/php.ini
	sed -i 's/display_errors = Off/display_errors = On/g' ${php_Path}/etc/php.ini
	sed -i 's/error_reporting =.*/error_reporting = E_ALL \& \~E_NOTICE/g' ${php_Path}/etc/php.ini

	# 设置SSL根证书
	sed -i "s#;openssl.cafile=#openssl.cafile=/etc/pki/tls/certs/ca-bundle.crt#" ${php_Path}/etc/php.ini
	sed -i "s#;curl.cainfo =#curl.cainfo = /etc/pki/tls/certs/ca-bundle.crt#" ${php_Path}/etc/php.ini

	# 关闭php外显
	sed -i 's/expose_php = On/expose_php = Off/g' ${php_Path}/etc/php.ini

	# 添加php-fpm到服务
	\cp ${php_Path}/src/sapi/fpm/php-fpm.service /lib/systemd/system/php-fpm-panel.service
	sed -i "s#ExecStart=/www/server/php/panel/sbin/php-fpm --nodaemonize --fpm-config /www/server/php/panel/etc/php-fpm.conf#ExecStart=/www/server/php/panel/sbin/php-fpm -R --nodaemonize --fpm-config /www/server/php/panel/etc/php-fpm.conf#g" /lib/systemd/system/php-fpm-panel.service
	sed -i "/PrivateTmp/d" /lib/systemd/system/php-fpm-panel.service
	sed -i "s/ProtectSystem=full/ProtectSystem=false/g" /lib/systemd/system/php-fpm-panel.service
	sed -i "s/PrivateDevices=true/PrivateDevices=false/g" /lib/systemd/system/php-fpm-panel.service
	sed -i "s/ProtectKernelModules=true/ProtectKernelModules=false/g" /lib/systemd/system/php-fpm-panel.service
	sed -i "s/ProtectKernelTunables=true/ProtectKernelTunables=false/g" /lib/systemd/system/php-fpm-panel.service
	sed -i "s/ProtectControlGroups=true/ProtectControlGroups=false/g" /lib/systemd/system/php-fpm-panel.service
	systemctl daemon-reload

	# 启动php
	systemctl enable php-fpm-panel.service
	systemctl start php-fpm-panel.service

}

Download_Nginx() {
	# 准备安装目录
	mkdir -p ${nginx_Path}
	rm -rf ${nginx_Path}/src
	cd ${nginx_Path}

	# 下载源码
	wget -T 120 -O ${nginx_Path}/openresty-${nginx_Version}.tar.gz ${download_Url}/nginx/openresty-${nginx_Version}.tar.gz
	tar -xvf openresty-${nginx_Version}.tar.gz
	rm -f openresty-${nginx_Version}.tar.gz
	mv openresty-${nginx_Version} src
	cd src

	# openssl
	wget -T 120 -O openssl.tar.gz ${download_Url}/nginx/openssl-${openssl_Version}.tar.gz
	tar -zxvf openssl.tar.gz
	rm -f openssl.tar.gz
	mv openssl-${openssl_Version} openssl
	rm -f openssl.tar.gz

	# pcre
	wget -T 60 -O pcre-8.45.tar.gz ${download_Url}/nginx/pcre-8.45.tar.gz
	tar -zxvf pcre-8.45.tar.gz
	rm -f pcre-8.45.tar.gz
	mv pcre-8.45 pcre
	rm -f pcre-8.45.tar.gz

	# ngx_cache_purge
	wget -T 20 -O ngx_cache_purge.tar.gz ${download_Url}/nginx/ngx_cache_purge-2.3.tar.gz
	tar -zxvf ngx_cache_purge.tar.gz
	rm -f ngx_cache_purge.tar.gz
	mv ngx_cache_purge-2.3 ngx_cache_purge
	rm -f ngx_cache_purge.tar.gz

	# nginx-sticky-module
	wget -T 20 -O nginx-sticky-module.zip ${download_Url}/nginx/nginx-sticky-module.zip
	unzip -o nginx-sticky-module.zip
	rm -f nginx-sticky-module.zip

	# nginx-dav-ext-module
	wget -T 20 -O nginx-dav-ext-module-3.0.0.tar.gz ${download_Url}/nginx/nginx-dav-ext-module-3.0.0.tar.gz
	tar -xvf nginx-dav-ext-module-3.0.0.tar.gz
	rm -f nginx-dav-ext-module-3.0.0.tar.gz
	mv nginx-dav-ext-module-3.0.0 nginx-dav-ext-module

	# waf
	cd ${nginx_Path}
	git clone -b lts https://magic.cdn.wepublish.cn/https://github.com/ADD-SP/ngx_waf.git
	git clone https://gitee.com/mirrors/uthash.git
	cd ngx_waf/inc
	wget -T 60 -O libinjection.zip ${download_Url}/nginx/libinjection-3.10.0.zip
	unzip -o libinjection.zip
	mv libinjection-3.10.0 libinjection
	rm -rf libinjection.zip
	cd ../
	make -j${cpuCore}
	if [ "$?" != "0" ]; then
		echo -e $HR
		echo "错误：面板OpenResty waf拓展初始化失败，请截图错误信息寻求帮助。"
		rm -rf ${nginx_Path}
		exit 1
	fi
	cd ${nginx_Path}/src

	# brotli
	wget -T 20 -O ngx_brotli.zip ${download_Url}/nginx/ngx_brotli-1.0.0rc.zip
	unzip -o ngx_brotli.zip
	mv ngx_brotli-1.0.0rc ngx_brotli
	cd ngx_brotli/deps
	rm -rf brotli
	wget -T 20 -O brotli.zip ${download_Url}/nginx/brotli-1.0.9.zip
	unzip -o brotli.zip
	mv brotli-1.0.9 brotli
	cd ${nginx_Path}/src
}

Install_Nginx() {

	cd ${nginx_Path}/src
	export LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
	export LIB_UTHASH=${nginx_Path}/uthash

	./configure --user=www --group=www --prefix=${nginx_Path} --with-luajit --add-module=${nginx_Path}/src/ngx_cache_purge --add-module=${nginx_Path}/src/nginx-sticky-module --with-openssl=${nginx_Path}/src/openssl --with-pcre=${nginx_Path}/src/pcre --with-http_v2_module --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_stub_status_module --with-http_ssl_module --with-http_image_filter_module --with-http_gzip_static_module --with-http_gunzip_module --with-ipv6 --with-http_sub_module --with-http_flv_module --with-http_addition_module --with-http_realip_module --with-http_mp4_module --with-ld-opt="-Wl,-E" --with-cc-opt="-O2 -std=gnu99" --with-cpu-opt="amd64" --with-http_dav_module --add-module=${nginx_Path}/src/nginx-dav-ext-module --add-module=${nginx_Path}/src/ngx_brotli --add-module=${nginx_Path}/ngx_waf
	make -j${cpuCore}
	if [ "$?" != "0" ]; then
		echo -e $HR
		echo "提示：面板OpenResty多线程编译失败，尝试单线程编译..."
		make
		if [ "$?" != "0" ]; then
			echo -e $HR
			echo "错误：OpenResty编译失败，请截图错误信息寻求帮助。"
			rm -rf ${nginx_Path}
			exit 1
		fi
	fi
	make install
	if [ ! -f "${nginx_Path}/nginx/sbin/nginx" ]; then
		echo -e $HR
		echo "错误：OpenResty安装失败，请截图错误信息寻求帮助。"
		rm -rf ${nginx_Path}
		exit 1
	fi

	# 设置软链接
	ln -sf ${nginx_Path}/nginx/html ${nginx_Path}/html
	ln -sf ${nginx_Path}/nginx/conf ${nginx_Path}/conf
	ln -sf ${nginx_Path}/nginx/logs ${nginx_Path}/logs
	ln -sf ${nginx_Path}/nginx/sbin ${nginx_Path}/sbin
	ln -sf ${nginx_Path}/nginx/sbin/nginx /usr/bin/nginx
	rm -f ${nginx_Path}/conf/nginx.conf

	# 创建配置目录
	cd ${nginx_Path}
	rm -f openresty-${nginx_Version}.tar.gz
	rm -rf src
	mkdir -p /www/wwwroot/default
	mkdir -p /www/wwwlogs
	mkdir -p /usr/local/nginx/logs
	mkdir -p /www/server/vhost
	mkdir -p /www/server/vhost/rewrite
	mkdir -p /www/server/vhost/ssl

	# 写入nginx主配置文件
	cat >${nginx_Path}/conf/nginx.conf <<EOF
# 该文件非必要勿修改，如实需修改，请加于文件尾部
user www www;
worker_processes auto;
error_log /www/wwwlogs/nginx_error.log crit;
pid /www/server/nginx/logs/nginx.pid;
worker_rlimit_nofile 51200;

stream {
    log_format tcp_format '\$time_local|\$remote_addr|\$protocol|\$status|\$bytes_sent|\$bytes_received|\$session_time|\$upstream_addr|\$upstream_bytes_sent|\$upstream_bytes_received|\$upstream_connect_time';

    access_log /www/wwwlogs/tcp-access.log tcp_format;
    error_log /www/wwwlogs/tcp-error.log;
}

events {
    use epoll;
    worker_connections 51200;
    multi_accept on;
}

http {
    include mime.types;
    include proxy.conf;
    default_type application/octet-stream;

    server_names_hash_bucket_size 512;
    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;
    client_max_body_size 50m;

    sendfile on;
    tcp_nopush on;

    keepalive_timeout 60;

    tcp_nodelay on;

    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
    fastcgi_buffer_size 64k;
    fastcgi_buffers 8 64k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    fastcgi_intercept_errors on;

    gzip on;
    gzip_min_length 1k;
    gzip_buffers 32 4k;
    gzip_http_version 1.1;
    gzip_comp_level 6;
    gzip_types *;
    gzip_vary on;
    gzip_proxied any;
    gzip_disable "MSIE [1-6]\.";
    brotli on;
    brotli_comp_level 6;
    brotli_min_length 10;
    brotli_window 1m;
    brotli_types *;
    brotli_static on;

    limit_conn_zone \$binary_remote_addr zone=perip:10m;
    limit_conn_zone \$server_name zone=perserver:10m;

    server_tokens off;
    access_log off;

    # 面板（请勿修改）
    server {
        listen 8888;
        server_name panel;
        index index.php;
        root /www/panel/public;

        include enable-php-panel.conf;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        access_log /www/wwwlogs/panel.log;
    }
    # 服务状态页
    server {
        listen 80;
        server_name 127.0.0.1;
        allow 127.0.0.1;

        location /nginx_status {
            stub_status on;
            access_log off;
        }
        location /phpfpm_panel_status {
            fastcgi_pass unix:/tmp/php-cgi-panel.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_74_status {
            fastcgi_pass unix:/tmp/php-cgi-74.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_75_status {
            fastcgi_pass unix:/tmp/php-cgi-75.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_76_status {
            fastcgi_pass unix:/tmp/php-cgi-76.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_77_status {
            fastcgi_pass unix:/tmp/php-cgi-77.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_78_status {
            fastcgi_pass unix:/tmp/php-cgi-78.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_79_status {
            fastcgi_pass unix:/tmp/php-cgi-79.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_80_status {
            fastcgi_pass unix:/tmp/php-cgi-80.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_81_status {
            fastcgi_pass unix:/tmp/php-cgi-81.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_82_status {
            fastcgi_pass unix:/tmp/php-cgi-82.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_83_status {
            fastcgi_pass unix:/tmp/php-cgi-83.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_84_status {
            fastcgi_pass unix:/tmp/php-cgi-84.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_85_status {
            fastcgi_pass unix:/tmp/php-cgi-85.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_86_status {
            fastcgi_pass unix:/tmp/php-cgi-86.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_87_status {
            fastcgi_pass unix:/tmp/php-cgi-87.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_88_status {
            fastcgi_pass unix:/tmp/php-cgi-88.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_89_status {
            fastcgi_pass unix:/tmp/php-cgi-89.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_90_status {
            fastcgi_pass unix:/tmp/php-cgi-90.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_91_status {
            fastcgi_pass unix:/tmp/php-cgi-91.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_92_status {
            fastcgi_pass unix:/tmp/php-cgi-92.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_93_status {
            fastcgi_pass unix:/tmp/php-cgi-93.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_94_status {
            fastcgi_pass unix:/tmp/php-cgi-94.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_95_status {
            fastcgi_pass unix:/tmp/php-cgi-95.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_96_status {
            fastcgi_pass unix:/tmp/php-cgi-96.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_97_status {
            fastcgi_pass unix:/tmp/php-cgi-97.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_98_status {
            fastcgi_pass unix:/tmp/php-cgi-98.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_99_status {
            fastcgi_pass unix:/tmp/php-cgi-99.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_100_status {
            fastcgi_pass unix:/tmp/php-cgi-100.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_101_status {
            fastcgi_pass unix:/tmp/php-cgi-101.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_102_status {
            fastcgi_pass unix:/tmp/php-cgi-102.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_103_status {
            fastcgi_pass unix:/tmp/php-cgi-103.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_104_status {
            fastcgi_pass unix:/tmp/php-cgi-104.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_105_status {
            fastcgi_pass unix:/tmp/php-cgi-105.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_106_status {
            fastcgi_pass unix:/tmp/php-cgi-106.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_107_status {
            fastcgi_pass unix:/tmp/php-cgi-107.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_108_status {
            fastcgi_pass unix:/tmp/php-cgi-108.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_109_status {
            fastcgi_pass unix:/tmp/php-cgi-109.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_110_status {
            fastcgi_pass unix:/tmp/php-cgi-110.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_111_status {
            fastcgi_pass unix:/tmp/php-cgi-111.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_112_status {
            fastcgi_pass unix:/tmp/php-cgi-112.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_113_status {
            fastcgi_pass unix:/tmp/php-cgi-113.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_114_status {
            fastcgi_pass unix:/tmp/php-cgi-114.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_115_status {
            fastcgi_pass unix:/tmp/php-cgi-115.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_116_status {
            fastcgi_pass unix:/tmp/php-cgi-116.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_117_status {
            fastcgi_pass unix:/tmp/php-cgi-117.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_118_status {
            fastcgi_pass unix:/tmp/php-cgi-118.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_119_status {
            fastcgi_pass unix:/tmp/php-cgi-119.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_120_status {
            fastcgi_pass unix:/tmp/php-cgi-120.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_121_status {
            fastcgi_pass unix:/tmp/php-cgi-121.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_122_status {
            fastcgi_pass unix:/tmp/php-cgi-122.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_123_status {
            fastcgi_pass unix:/tmp/php-cgi-123.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_124_status {
            fastcgi_pass unix:/tmp/php-cgi-124.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_125_status {
            fastcgi_pass unix:/tmp/php-cgi-125.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_126_status {
            fastcgi_pass unix:/tmp/php-cgi-126.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_127_status {
            fastcgi_pass unix:/tmp/php-cgi-127.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_128_status {
            fastcgi_pass unix:/tmp/php-cgi-128.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
        location /phpfpm_129_status {
            fastcgi_pass unix:/tmp/php-cgi-129.sock;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        }
    }
    include /www/server/vhost/*.conf;
}
EOF
	# 写入nginx pathinfo配置文件
	cat >${nginx_Path}/conf/pathinfo.conf <<EOF
set \$real_script_name \$fastcgi_script_name;
if (\$fastcgi_script_name ~ "^(.+?\.php)(/.+)$") {
    set \$real_script_name \$1;
    set \$path_info \$2;
 }
fastcgi_param SCRIPT_FILENAME \$document_root\$real_script_name;
fastcgi_param SCRIPT_NAME \$real_script_name;
fastcgi_param PATH_INFO \$path_info;
EOF
	# 写入nginx 调用面板php配置文件
	cat >${nginx_Path}/conf/enable-php-panel.conf <<EOF
location ~ [^/]\.php(/|$) {
    try_files \$uri =404;
    fastcgi_pass unix:/tmp/php-cgi-panel.sock;
    fastcgi_index index.php;
    include fastcgi.conf;
    include pathinfo.conf;
}
EOF
	# 写入nginx 默认站点页
	cat >${nginx_Path}/html/index.html <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>耗子Linux面板</title>
</head>
<body>
<h1>耗子Linux面板</h1>
<p>这是耗子Linux面板的OpenResty默认页面！</p>
<p>当您看到此页面，说明尚未添加域名与站点绑定。</p>
</body>
</html>
EOF

	# 写入nginx 站点停止页
	cat >${nginx_Path}/html/stop.html <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>网站已停止 - 耗子Linux面板</title>
</head>
<body>
<h1>耗子Linux面板</h1>
<p>该网站已被管理员停止访问！</p>
<p>当您看到此页面，该网站已被管理员停止对外访问，请联系管理员了解详情。</p>
</body>
</html>
EOF

	# 处理文件权限
	chmod 755 /www/server/nginx/
	chmod 755 /www/server/nginx/html/
	chmod -R 755 /www/wwwroot/
	chown -R www:www /www/wwwroot/
	chmod 644 /www/server/nginx/html/*

	# 写入nginx 无php配置文件
	echo "" >${nginx_Path}/conf/enable-php-00.conf
	# 写入nginx 代理默认配置文件
	cat >${nginx_Path}/conf/proxy.conf <<EOF
proxy_temp_path ${nginx_Path}/proxy_temp_dir;
proxy_cache_path ${nginx_Path}/proxy_cache_dir levels=1:2 keys_zone=cache_one:20m inactive=1d max_size=5g;
client_body_buffer_size 512k;
proxy_connect_timeout 60;
proxy_read_timeout 60;
proxy_send_timeout 60;
proxy_buffer_size 32k;
proxy_buffers 4 64k;
proxy_busy_buffers_size 128k;
proxy_temp_file_write_size 128k;
proxy_next_upstream error timeout invalid_header http_500 http_503 http_404;
proxy_cache cache_one;
EOF

	# 下载dh密钥
	wget -T 20 -O /etc/ssl/certs/dhparam.pem https://ssl-config.mozilla.org/ffdhe2048.txt
	# 建立日志目录
	mkdir -p /www/wwwlogs/waf
	chown www.www /www/wwwlogs/waf
	chmod 755 /www/wwwlogs/waf

	# 写入服务文件
	cat >/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target
Wants=network.target

[Service]
Type=forking
PIDFile=/www/server/nginx/logs/nginx.pid
ExecStartPre=/www/server/nginx/sbin/nginx -t -c /www/server/nginx/conf/nginx.conf
ExecStart=/www/server/nginx/sbin/nginx -c /www/server/nginx/conf/nginx.conf
ExecReload=/www/server/nginx/sbin/nginx -s reload
ExecStop=/www/server/nginx/sbin/nginx -s quit

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload

	# 启动Nginx
	systemctl enable nginx.service
	systemctl start nginx.service
	rm -rf ${nginx_Path}/src
}

Init_Panel() {
	mkdir /www/panel
	# 下载面板zip包并解压
	wget -O /www/panel/panel.zip "https://api.panel.haozi.xyz/api/version/latest"
	cd /www/panel
	unzip -o panel.zip
	rm -rf panel.zip
	# 写入面板命令别名
	echo "alias panel='php-panel /www/panel/artisan panel'" >>/etc/profile
	source /etc/profile
	. /etc/profile
	# 防火墙放行
	systemctl enable firewalld
	systemctl start firewalld
	firewall-cmd --set-default-zone=public >/dev/null 2>&1
	firewall-cmd --permanent --zone=public --add-port=22/tcp >/dev/null 2>&1
	firewall-cmd --permanent --zone=public --add-port=80/tcp >/dev/null 2>&1
	firewall-cmd --permanent --zone=public --add-port=443/tcp >/dev/null 2>&1
	firewall-cmd --permanent --zone=public --add-port=8888/tcp >/dev/null 2>&1
	firewall-cmd --permanent --zone=public --add-port=${sshPort}/tcp >/dev/null 2>&1
	firewall-cmd --reload
	# 写入服务文件
	cat >/lib/systemd/system/panel.service <<EOF
[Unit]
Description=HaoZi Linux Panel
After=syslog.target network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/www/panel/
ExecStart=php-panel artisan queue:work
ExecReload=php-panel artisan queue:restart
ExecStop=pkill php-panel
User=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable panel.service
	systemctl start panel.service
	# 写入计划任务
	echo "*/1 * * * * php-panel /www/panel/artisan schedule:run >> /dev/null 2>&1" >>/var/spool/cron/root
	# 重载计划任务
	crontab /var/spool/cron/root
	# 写入OpenResty插件安装状态
	php-panel artisan panel writePluginInstall openresty

	clear
	echo -e $LOGO
	echo '面板安装成功！'
	echo -e $HR
	php-panel artisan panel init
	php-panel artisan panel getInfo
}

clear
echo -e $LOGO
# 安装确认
read -p "面板将安装至/www目录，请输入 y 并回车以开始安装：" install
if [ "$install" != 'y' ]; then
	echo "输入不正确，已退出安装。"
	exit
fi

clear
echo -e $LOGO
echo '安装面板依赖软件（如报错请检查 Dnf/Yum 源是否正常）'
echo -e $HR
sleep 3s
Prepare_system
Auto_Swap

clear
echo -e $LOGO
echo '安装面板运行环境（视服务器配置可能需要较长时间）'
echo -e $HR
sleep 3s
Download_Php
Install_Php
Download_Nginx
Install_Nginx

clear
echo -e $LOGO
echo '初始化面板配置...'
echo -e $HR
sleep 3s
Init_Panel
