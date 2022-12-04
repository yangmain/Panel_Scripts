#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"       # 操作
setup_Path="/www" # 面板安装目录

Install() {
    # 安装插件
    rm -rf /www/panel/plugins/AutoBackup
    mkdir /www/panel/plugins/AutoBackup
    wget -O /www/panel/plugins/AutoBackup/auto-backup.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=auto-backup"
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：下载失败，请检查网络是否正常。"
        exit 1
    fi
    cd /www/panel/plugins/AutoBackup
    unzip -o auto-backup.zip && rm -rf auto-backup.zip
    # 写入插件安装状态
    panel writePluginInstall auto-backup
}

Uninstall() {
    # 删除插件
    rm -rf /www/panel/plugins/AutoBackup
    panel writePluginUnInstall auto-backup
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
if [ "$action" == 'update' ]; then
    Uninstall
    Install
fi
