#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1" # 操作

Install() {
    dnf install pure-ftpd -y
    # 检查是否安装成功
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：pure-ftpd安装失败，请截图错误信息寻求帮助。"
        exit 1
    fi
    # 修改 pure-ftpd 配置文件
    sed -i 's!# PureDB\s*@sysconfigdir@/pureftpd.pdb!PureDB /etc/pure-ftpd/pureftpd.pdb!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!# ChrootEveryone\s*yes!ChrootEveryone yes!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!NoAnonymous\s*no!NoAnonymous yes!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!AnonymousCanCreateDirs\s*yes!AnonymousCanCreateDirs no!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!AnonymousCantUpload\s*yes!AnonymousCantUpload no!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!# PAMAuthentication\s*yes!PAMAuthentication yes!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!PAMAuthentication\s*no!PAMAuthentication yes!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!UnixAuthentication\s*yes!UnixAuthentication no!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!# PassivePortRange\s*30000 50000!PassivePortRange 39000 40000!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!PassivePortRange\s*30000 50000!PassivePortRange 39000 40000!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!LimitRecursion\s*10000 8!LimitRecursion 20000 8!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!# TLS\s*1!TLS 0!' /etc/pure-ftpd/pure-ftpd.conf
    sed -i 's!# Bind\s*127.0.0.1,21!Bind 0.0.0.0,21!' /etc/pure-ftpd/pure-ftpd.conf
    touch /etc/pure-ftpd/pureftpd.passwd
    touch /etc/pure-ftpd/pureftpd.pdb
    #echo "AllowOverwrite yes" >>/etc/pure-ftpd/pure-ftpd.conf
    #echo "AllowStoreRestart yes" >>/etc/pure-ftpd/pure-ftpd.conf
    # 放行端口
    firewall-cmd --permanent --zone=public --add-port=21/tcp
    firewall-cmd --permanent --zone=public --add-port=39000-40000/tcp
    # 重载防火墙
    firewall-cmd --reload
    # 启动 pure-ftpd
    systemctl enable pure-ftpd
    systemctl start pure-ftpd

    # 安装 pure-ftpd 插件
    rm -rf /www/panel/plugins/PureFtpd
    mkdir /www/panel/plugins/PureFtpd
    wget -O /www/panel/plugins/PureFtpd/pure-ftpd.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=pure-ftpd"
    cd /www/panel/plugins/PureFtpd
    unzip -o pure-ftpd.zip && rm -rf pure-ftpd.zip
    # 写入插件安装状态
    panel writePluginInstall pure-ftpd
}

Uninstall() {
    # 停止 pure-ftpd
    systemctl stop pure-ftpd
    systemctl disable pure-ftpd
    # 删除 pure-ftpd
    dnf remove pure-ftpd -y
    # 删除插件
    rm -rf /www/panel/plugins/PureFtpd
    panel writePluginUnInstall pure-ftpd
    # 删除配置目录
    rm -rf /etc/pure-ftpd
}

Update() {
    # 停止 pure-ftpd
    systemctl stop pure-ftpd
    # 更新 pure-ftpd
    dnf update pure-ftpd -y
    # 启动 pure-ftpd
    systemctl start pure-ftpd
    # 更新插件
    rm -rf /www/panel/plugins/PureFtpd
    mkdir /www/panel/plugins/PureFtpd
    wget -O /www/panel/plugins/PureFtpd/pure-ftpd.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=pure-ftpd"
    cd /www/panel/plugins/PureFtpd
    unzip -o pure-ftpd.zip && rm -rf pure-ftpd.zip
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
if [ "$action" == 'update' ]; then
    Update
fi
