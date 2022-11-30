#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"                # 操作
phpmyadmin_Version="5.2.0" # phpMyAdmin版本

setup_Path="/www"                                                  # 面板安装目录
phpmyadmin_Path="${setup_Path}/wwwroot/phpmyadmin"                 # phpMyAdmin目录
randomDir="$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)" # 随机目录

Download() {
    # 准备安装目录
    rm -rf ${phpmyadmin_Path}
    mkdir -p ${phpmyadmin_Path}
    cd ${phpmyadmin_Path}

    wget -O phpmyadmin.zip https://files.phpmyadmin.net/phpMyAdmin/${phpmyadmin_Version}/phpMyAdmin-${phpmyadmin_Version}-all-languages.zip
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：phpMyAdmin 下载失败"
        rm -rf ${phpmyadmin_Path}
        exit 1
    fi
    unzip phpmyadmin.zip
    mv phpMyAdmin-${phpmyadmin_Version}-all-languages phpmyadmin_${randomDir}
    chown -R www:www ${phpmyadmin_Path}
    chmod -R 755 ${phpmyadmin_Path}
    rm -rf phpmyadmin.zip
}

Install() {
    # 写入 phpMyAdmin 配置文件
    cat >/www/server/vhost/phpmyadmin.conf <<EOF
# 配置文件中的标记位请勿随意修改，改错将导致面板无法识别！
# 有自定义配置需求的，请将自定义的配置写在各标记位下方。
server
{
    # port标记位开始
    listen 888;
    # port标记位结束
    # server_name标记位开始
    server_name phpmyadmin;
    # server_name标记位结束
    # index标记位开始
    index index.php;
    # index标记位结束
    # root标记位开始
    root /www/wwwroot/phpmyadmin;
    # root标记位结束

    # php标记位开始
    include enable-php-panel.conf;
    # php标记位结束

    # 面板默认禁止访问部分敏感目录，可自行修改
    location ~ ^/(\.user.ini|\.htaccess|\.git|\.svn)
    {
        return 404;
    }
    location ~ /tmp/ {
        return 403;
    }
    # 面板默认不记录静态资源的访问日志并开启1小时浏览器缓存，可自行修改
    location ~ .*\.(js|css)$
    {
        expires 1h;
        error_log /dev/null;
        access_log /dev/null;
    }
    access_log /www/wwwlogs/phpmyadmin.log;
    error_log /www/wwwlogs/phpmyadmin.log;
}
EOF

    # 安装 phpMyAdmin 插件
    rm -rf /www/panel/plugins/Phpmyadmin
    mkdir /www/panel/plugins/Phpmyadmin
    wget -O /www/panel/plugins/Phpmyadmin/phpmyadmin.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=phpmyadmin"
    cd /www/panel/plugins/Phpmyadmin
    unzip phpmyadmin.zip && rm -rf phpmyadmin.zip
    # 写入插件安装状态
    panel writePluginInstall phpmyadmin
    # 重载 OpenResty
    systemctl reload nginx
}

Uninstall() {
    # 删除 phpMyAdmin 配置文件
    rm -rf /www/server/vhost/phpmyadmin.conf
    # 删除 phpMyAdmin 目录
    rm -rf ${phpmyadmin_Path}
    # 删除插件
    rm -rf /www/panel/plugins/Phpmyadmin
    panel writePluginUnInstall phpmyadmin
    # 重载 OpenResty
    systemctl reload nginx
}

if [ "$action" == 'install' ]; then
    Download
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
if [ "$action" == 'update' ]; then
    Uninstall
    Download
    Install
fi
