#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"        # 操作
postgresql_Version="$2" # PostgreSQL版本

download_Url="https://dl-cdn.haozi.xyz" # 下载节点
setup_Path="/www"                       # 面板安装目录
postgresql_Path="${setup_Path}/server/postgresql" # PostgreSQL目录

Download_PostgreSQL() {
    # 准备安装目录
    rm -rf ${mysql_Path}
    mkdir -p ${mysql_Path}
    cd ${mysql_Path}

    rpm -Uvh https://mirrors.aliyun.com/postgresql/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    sed -i "s@https://download.postgresql.org/pub@https://mirrors.aliyun.com/postgresql@g" /etc/yum.repos.d/pgdg-redhat-all.repo
    sudo dnf -qy module disable postgresql
    sudo dnf install -y postgresql${postgresql_Version}-server postgresql${postgresql_Version}-devel
    sed -i "s@Environment=PGDATA=/var/lib/pgsql/15/data/@Environment=PGDATA=${postgresql_Path}/${postgresql_Version}@g" /usr/lib/systemd/system/postgresql-${postgresql_Version}.service
}

Install_PostgreSQL() {
    # 启动 PostgreSQL
    sudo /usr/pgsql-${postgresql_Version}/bin/postgresql-${postgresql_Version}-setup initdb
    sudo systemctl enable postgresql-${postgresql_Version}
    sudo systemctl start postgresql-${postgresql_Version}
    # php需要安装libpq才能加载pdo_pgsql拓展（postgresql-devel）

    # 安装 PostgreSQL 插件
}

Uninstall_PostgreSQL() {
    # 停止 PostgreSQL
    systemctl stop postgresql${postgresql_Version}-server
    systemctl disable postgresql${postgresql_Version}-server
    # 删除 PostgreSQL
    dnf remove postgresql${postgresql_Version}-server -y
    # 删除插件
    rm -rf /www/panel/plugins/postgresql-${postgresql_Version}
}

Update_PostgreSQL() {
    # 停止 PostgreSQL
    systemctl stop postgresql${postgresql_Version}-server
    # 更新 PostgreSQL
    dnf update postgresql${postgresql_Version}-server -y
    # 启动 PostgreSQL
    systemctl start postgresql${postgresql_Version}-server
    # 更新插件
    #mysqlPluginVersion = $(wget -qO- -t1 -T2 "https://api.panel.haozi.xyz/api/plugin/version?slug=mysql")
    #mysqlPluginUrl = $(wget -qO- -t1 -T2 "https://api.panel.haozi.xyz/api/plugin/url?slug=mysql")
    rm -rf /www/panel/plugins/postgresql${postgresql_Version}
    mkdir /www/panel/plugins/postgresql${postgresql_Version}
    #wget -O /www/panel/plugins/mysql/mysql.zip ${mysqlPluginUrl}
    #cd /www/panel/plugins/mysql
    #unzip mysql.zip && rm -rf mysql.zip
}

if [ "$action" == 'install' ]; then
    Download_PostgreSQL
    Install_PostgreSQL
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall_PostgreSQL
fi
if [ "$action" == 'update' ]; then
    Update_PostgreSQL
fi
