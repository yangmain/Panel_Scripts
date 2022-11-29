#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

download_Url="https://dl.panel.haozi.xyz" # 下载节点
action="$1"                               # 操作
php_Version="$2"                          # PHP版本
imagick_Version="3.7.0"                   # imagick版本

Install() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^extension=imagick$')
    if [ "${isInstall}" != "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 已安装 imagick"
        exit 1
    fi

    # 安装依赖
    dnf install ImageMagick ImageMagick-devel -y

    cd /www/server/php/${php_Version}/src/ext
    rm -rf imagick
    rm -rf imagick.tar.gz
    wget -O imagick.tar.gz ${download_Url}/php-ext/imagick-${imagick_Version}.tar.gz
    tar -zxvf imagick.tar.gz
    mv imagick-${imagick_Version} imagick
    cd imagick
    /www/server/php/${php_Version}/bin/phpize
    ./configure --with-php-config=/www/server/php/${php_Version}/bin/php-config
    make
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "PHP-${php_Version} imagick 编译失败"
        exit 1
    fi
    make install
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "PHP-${php_Version} imagick 安装失败"
        exit 1
    fi

    sed -i '/;haozi/a\extension=imagick' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} imagick 安装成功"
}

Uninstall() {
    # 检查是否已经安装
    isInstall=$(cat /www/server/php/${php_Version}/etc/php.ini | grep '^extension=imagick$')
    if [ "${isInstall}" == "" ]; then
        echo -e $HR
        echo "PHP-${php_Version} 未安装 imagick"
        exit 1
    fi

    sed -i '/extension=imagick/d' /www/server/php/${php_Version}/etc/php.ini

    # 重载PHP
    systemctl reload php-fpm-${php_Version}.service
    echo -e $HR
    echo "PHP-${php_Version} imagick 卸载成功"
}

if [ "$action" == 'install' ]; then
    Install
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall
fi
