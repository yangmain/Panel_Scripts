#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"        # 操作
redis_Version="$2" # Redis版本

Download_Redis() {
    dnf module enable redis:${redis_Version} -y
    dnf install redis -y
}

Install_Redis() {
    # 启动 Redis
    systemctl enable redis
    systemctl start redis

    # 安装 Redis 插件
}

Uninstall_Redis() {
    # 停止 Redis
    systemctl stop redis
    systemctl disable redis
    # 删除 Redis
    dnf remove redis -y
    # 删除插件
    rm -rf /www/panel/plugins/redis
}

Update_Redis() {
    # 停止redis
    systemctl stop redis
    # 更新redis
    dnf update redis -y
    # 启动redis
    systemctl start redis
    # 更新插件
    #mysqlPluginVersion = $(wget -qO- -t1 -T2 "https://api.panel.haozi.xyz/api/plugin/version?slug=mysql")
    #mysqlPluginUrl = $(wget -qO- -t1 -T2 "https://api.panel.haozi.xyz/api/plugin/url?slug=mysql")
    rm -rf /www/panel/plugins/redis
    mkdir /www/panel/plugins/redis
    #wget -O /www/panel/plugins/mysql/mysql.zip ${mysqlPluginUrl}
    #cd /www/panel/plugins/mysql
    #unzip mysql.zip && rm -rf mysql.zip
}

if [ "$action" == 'install' ]; then
    Download_Redis
    Install_Redis
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall_Redis
fi
if [ "$action" == 'update' ]; then
    Update_Redis
fi
