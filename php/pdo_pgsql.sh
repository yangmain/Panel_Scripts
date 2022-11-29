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
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^extension=pdo_pgsql$')
    if [ "${isInstall}" != "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 已安装 pdo_pgsql"
        exit 1
    fi

    cd /www/server/php/${php_Version}/src/ext/pdo_pgsql
    /www/server/php/${php_Version}/bin/phpize
    ./configure --with-php-config=/www/server/php/${php_Version}/bin/php-config --with-pdo-pgsql=/usr/pgsql-15
    make
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "PHP-${php_Version} pdo_pgsql 编译失败"
        exit 1
    fi
    make install
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "PHP-${php_Version} pdo_pgsql 安装失败"
        exit 1
    fi

    sed -i '/;haozi/a\extension=pdo_pgsql' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} pdo_pgsql 安装成功"
}

Uninstall() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^extension=pdo_pgsql$')
    if [ "${isInstall}" == "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 未安装 pdo_pgsql"
        exit 1
    fi

    sed -i '/extension=pdo_pgsql/d' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} pdo_pgsql 卸载成功"
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
