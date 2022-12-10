#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"       # 操作
setup_Path="/www" # 面板安装目录

Install() {
    # 安装s3fs
    dnf install -y s3fs-fuse
    # 检查是否安装成功
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：s3fs安装失败，请截图错误信息寻求帮助。"
        exit 1
    fi
    dnf install -y mailcap
    # 安装插件
    rm -rf /www/panel/plugins/S3fs
    mkdir /www/panel/plugins/S3fs
    wget -O /www/panel/plugins/S3fs/s3fs.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=s3fs"
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：下载失败，请检查网络是否正常。"
        exit 1
    fi
    cd /www/panel/plugins/S3fs
    unzip -o s3fs.zip && rm -rf s3fs.zip
    # 写入插件安装状态
    panel writePluginInstall s3fs
}

Uninstall() {
    # 删除s3fs
    dnf remove -y s3fs-fuse
    # 删除插件
    rm -rf /www/panel/plugins/S3fs
    panel writePluginUnInstall s3fs
}

Update() {
    dnf update -y s3fs-fuse
    # 更新插件
    rm -rf /www/panel/plugins/S3fs
    mkdir /www/panel/plugins/S3fs
    wget -O /www/panel/plugins/S3fs/s3fs.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=s3fs"
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：下载失败，请检查网络是否正常。"
        exit 1
    fi
    cd /www/panel/plugins/S3fs
    unzip -o s3fs.zip && rm -rf s3fs.zip
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
