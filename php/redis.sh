#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

download_Url="https://dl.panel.haozi.xyz" # 下载节点
action="$1"                               # 操作
php_Version="$2"                          # PHP版本
phpredis_Version="5.3.7"                  # phpredis版本

Install() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^extension=redis$')
    if [ "${isInstall}" != "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 已安装 redis"
        exit 1
    fi

    cd /www/server/php/${php_Version}/src/ext
    rm -rf phpredis
    rm -rf phpredis.tar.gz
    wget -O phpredis.tar.gz ${download_Url}/php-ext/phpredis-${phpredis_Version}.tar.gz
    tar -zxvf phpredis.tar.gz
    mv phpredis-${phpredis_Version} phpredis
    cd phpredis
    /www/server/php/${php_Version}/bin/phpize
    ./configure --with-php-config=/www/server/php/${php_Version}/bin/php-config
    make
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "PHP-${php_Version} redis 编译失败"
        exit 1
    fi
    make install
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "PHP-${php_Version} redis 安装失败"
        exit 1
    fi

    sed -i '/;haozi/a\extension=redis' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} redis 安装成功"
}

Uninstall() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^extension=redis$')
    if [ "${isInstall}" == "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 未安装 redis"
        exit 1
    fi

    sed -i '/extension=redis/d' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} redis 卸载成功"
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
