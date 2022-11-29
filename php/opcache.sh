#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"      # 操作
php_Version="$2" # PHP版本

Install() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^zend_extension=opcache$')
    if [ "${isInstall}" != "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 已安装 Zend OPcache"
        exit 1
    fi

    sed -i '/;haozi/a\zend_extension=opcache\nopcache.enable = 1\nopcache.enable_cli=1\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=32\nopcache.max_accelerated_files=100000\nopcache.revalidate_freq=3\nopcache.save_comments=0\nopcache.jit_buffer_size=128m\nopcache.jit=1205' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} Zend OPcache 安装成功"
}

Uninstall() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^zend_extension=opcache$')
    if [ "${isInstall}" == "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 未安装 Zend OPcache"
        exit 1
    fi

    sed -i '/^opcache.*$/d' /www/server/php/${php_Version}/etc/php.ini
    sed -i '/zend_extension=opcache/d' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} Zend OPcache 卸载成功"
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
