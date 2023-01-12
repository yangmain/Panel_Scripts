#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"                               # 操作
php_Version="$2"                          # PHP版本
download_Url="https://dl.panel.haozi.xyz" # 下载节点

Install() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep 'ioncube_loader_lin')
    if [ "${isInstall}" != "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 已安装 ionCube"
        exit 1
    fi

    mkdir /usr/local/ioncube
    wget -O /usr/local/ioncube/ioncube_loader_lin_${php_Version}.so ${download_Url}/php-ext/ioncube_loader_lin_${php_Version}.so
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：ionCube 下载失败，请检查网络是否正常。"
        exit 1
    fi
    sed -i -e "/;haozi/a\zend_extension=/usr/local/ioncube/ioncube_loader_lin_${php_Version}.so" /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} ionCube 安装成功"
}

Uninstall() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep 'ioncube_loader_lin')
    if [ "${isInstall}" == "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 未安装 ionCube"
        exit 1
    fi

    rm -f /usr/local/ioncube/ioncube_loader_lin_${php_Version}.so
    sed -i '/ioncube_loader_lin/d' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} ionCube 卸载成功"
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
