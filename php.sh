#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"      # 操作
php_Version="$2" # PHP版本

download_Url="https://dl.panel.haozi.xyz"               # 下载节点
setup_Path="/www"                                       # 面板安装目录
php_Path="${setup_Path}/server/php/${php_Version}"      # PHP目录
cpuCore=$(cat /proc/cpuinfo | grep "processor" | wc -l) # CPU核心数

Download_Php() {
    # 准备安装目录
    mkdir -p ${php_Path}
    rm -rf ${php_Path}/src
    cd ${php_Path}

    # 下载源码
    if [ "${php_Version}" == "74" ]; then
        wget -O ${php_Path}/php-${php_Version}.tar.gz ${download_Url}/php/php-7.4.33.tar.gz
    fi
    if [ "${php_Version}" == "80" ]; then
        wget -O ${php_Path}/php-${php_Version}.tar.gz ${download_Url}/php/php-8.0.27.tar.gz
    fi
    if [ "${php_Version}" == "81" ]; then
        wget -O ${php_Path}/php-${php_Version}.tar.gz ${download_Url}/php/php-8.1.15.tar.gz
    fi
    if [ "${php_Version}" == "82" ]; then
        wget -O ${php_Path}/php-${php_Version}.tar.gz ${download_Url}/php/php-8.2.2.tar.gz
    fi

    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：PHP-${php_Version}下载失败，请检查网络是否正常。"
        exit 1
    fi

    tar -xvf php-${php_Version}.tar.gz
    rm -f php-${php_Version}.tar.gz
    mv php-* src
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
        echo "错误：PHP-${php_Version}安装失败，请截图错误信息寻求帮助！"
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
        echo "错误：PHP-${php_Version} zip拓展安装失败，请截图错误信息寻求帮助。"
        exit 1
    fi
    cd ../../

    # 写入拓展标记位
    echo ";下方标记位禁止删除，否则将导致PHP拓展无法正常安装！" >>${php_Path}/etc/php.ini
    echo ";haozi" >>${php_Path}/etc/php.ini
    # 写入zip拓展到php配置
    echo "extension=zip" >>${php_Path}/etc/php.ini

    # 设置软链接
    rm -f /usr/bin/php-${php_Version}
    rm -f /usr/bin/pear
    rm -f /usr/bin/pecl
    ln -sf ${php_Path}/bin/php /usr/bin/php-${php_Version}
    ln -sf ${php_Path}/bin/phpize /usr/bin/phpize
    ln -sf ${php_Path}/bin/pear /usr/bin/pear
    ln -sf ${php_Path}/bin/pecl /usr/bin/pecl
    ln -sf ${php_Path}/sbin/php-fpm /usr/bin/php-fpm-${php_Version}

    # 设置fpm
    cat >${php_Path}/etc/php-fpm.conf <<EOF
[global]
pid = ${php_Path}/var/run/php-fpm.pid
error_log = ${php_Path}/var/log/php-fpm.log
log_level = notice

[www]
listen = /tmp/php-cgi-${php_Version}.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = www
listen.group = www
listen.mode = 0666
user = www
group = www
pm = dynamic
pm.max_children = 30
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
request_terminate_timeout = 100
request_slowlog_timeout = 30
pm.status_path = /phpfpm_${php_Version}_status
slowlog = var/log/slow.log
EOF
    # 设置PHP进程数
    mem_Total=$(free -m | grep Mem | awk '{print  $2}')
    if [[ ${mem_Total} -gt 1024 && ${mem_Total} -le 2048 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 50#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 10#" ${php_Path}/etc/php-fpm.conf
    elif [[ ${mem_Total} -gt 2048 && ${mem_Total} -le 4096 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 80#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 5#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 5#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 20#" ${php_Path}/etc/php-fpm.conf
    elif [[ ${mem_Total} -gt 4096 && ${mem_Total} -le 8192 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 150#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 10#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 10#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${php_Path}/etc/php-fpm.conf
    elif [[ ${mem_Total} -gt 8192 && ${mem_Total} -le 16384 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 200#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 15#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 15#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 30#" ${php_Path}/etc/php-fpm.conf
    elif [[ ${mem_Total} -gt 16384 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 300#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 20#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 20#" ${php_Path}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 50#" ${php_Path}/etc/php-fpm.conf
    fi
    sed -i "s#listen.backlog.*#listen.backlog = 8192#" ${php_Path}/etc/php-fpm.conf
    # 最大上传限制100M
    sed -i 's/post_max_size =.*/post_max_size = 100M/g' ${php_Path}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 100M/g' ${php_Path}/etc/php.ini
    # 时区PRC
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' ${php_Path}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' ${php_Path}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=1/g' ${php_Path}/etc/php.ini
    # 最大运行时间
    sed -i 's/max_execution_time =.*/max_execution_time = 86400/g' ${php_Path}/etc/php.ini
    sed -i 's/;sendmail_path =.*/sendmail_path = \/usr\/sbin\/sendmail -t -i/g' ${php_Path}/etc/php.ini
    # 禁用函数
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,putenv,chroot,chgrp,chown,shell_exec,popen,proc_open,pcntl_exec,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,imap_open,apache_setenv/g' ${php_Path}/etc/php.ini
    sed -i 's/display_errors = Off/display_errors = On/g' ${php_Path}/etc/php.ini
    sed -i 's/error_reporting =.*/error_reporting = E_ALL \& \~E_NOTICE/g' ${php_Path}/etc/php.ini

    # 设置SSL根证书
    sed -i "s#;openssl.cafile=#openssl.cafile=/etc/pki/tls/certs/ca-bundle.crt#" ${php_Path}/etc/php.ini
    sed -i "s#;curl.cainfo =#curl.cainfo = /etc/pki/tls/certs/ca-bundle.crt#" ${php_Path}/etc/php.ini

    # 关闭php外显
    sed -i 's/expose_php = On/expose_php = Off/g' ${php_Path}/etc/php.ini

    # 写入nginx 调用面板php配置文件
    cat >/www/server/nginx/conf/enable-php-${php_Version}.conf <<EOF
location ~ [^/]\.php(/|$) {
    try_files \$uri =404;
    fastcgi_pass unix:/tmp/php-cgi-${php_Version}.sock;
    fastcgi_index index.php;
    include fastcgi.conf;
    include pathinfo.conf;
}
EOF

    # 添加php-fpm到服务
    \cp ${php_Path}/src/sapi/fpm/php-fpm.service /lib/systemd/system/php-fpm-${php_Version}.service
    sed -i "/PrivateTmp/d" /lib/systemd/system/php-fpm-${php_Version}.service
    systemctl daemon-reload

    # 启动php
    systemctl enable php-fpm-${php_Version}.service
    systemctl start php-fpm-${php_Version}.service

    # 下载插件
    rm -rf /www/panel/plugins/Php${php_Version}
    mkdir /www/panel/plugins/Php${php_Version}
    wget -O /www/panel/plugins/Php${php_Version}/php${php_Version}.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=php${php_Version}"
    cd /www/panel/plugins/Php${php_Version}
    unzip -o php${php_Version}.zip && rm -rf php${php_Version}.zip
    # 写入插件安装状态
    panel writePluginInstall php${php_Version}
}

Uninstall_Php() {
    # 停止php-fpm
    systemctl stop php-fpm-$php_Version

    # 删除服务
    systemctl disable php-fpm-${php_version}
    rm -rf /lib/systemd/system/php-fpm-${php_Version}.service
    systemctl daemon-reload

    # 删除php目录
    rm -rf $php_Path

    # 删除php命令
    rm -f /usr/bin/php-${php_Version}

    # 删除插件
    rm -rf /www/panel/plugins/Php${php_Version}
    panel writePluginUnInstall php${php_Version}
}

if [ "$action" == 'install' ] || [ "$action" == 'update' ]; then
    Download_Php
    Install_Php
elif [ "$action" == 'uninstall' ]; then
    Uninstall_Php
fi
