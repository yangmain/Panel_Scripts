#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"             # 操作
postgresql_Version="$2" # PostgreSQL版本

setup_Path="/www"                                                       # 面板安装目录
postgresql_Path="${setup_Path}/server/postgresql"                       # PostgreSQL目录
os_Version=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\.?.*/\1/') # 系统版本
ipLocation=$(curl -s https://api.panel.haozi.xyz/api/ip/getIpLocation)  # 获取IP位置

Download_PostgreSQL() {
    # 准备安装目录
    rm -rf ${postgresql_Path}
    mkdir -p ${postgresql_Path}
    cd ${postgresql_Path}

    # 判断位置是否是中国
    if [[ ${ipLocation} == "中国" ]]; then
        rpm -Uvh https://mirrors.aliyun.com/postgresql/repos/yum/reporpms/EL-${os_Version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm
        sed -i "s@https://download.postgresql.org/pub@https://mirrors.aliyun.com/postgresql@g" /etc/yum.repos.d/pgdg-redhat-all.repo
    else
        rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-${os_Version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    fi
    sudo dnf -qy module disable postgresql
    sudo dnf install -y postgresql${postgresql_Version}-server postgresql${postgresql_Version}-devel
    # 检查是否安装成功
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：PostgreSQL安装失败，请截图错误信息寻求帮助。"
        exit 1
    fi
    sed -i "s@Environment=PGDATA=/var/lib/pgsql/${postgresql_Version}/data/@Environment=PGDATA=${postgresql_Path}/${postgresql_Version}@g" /usr/lib/systemd/system/postgresql-${postgresql_Version}.service
}

Install_PostgreSQL() {
    # 启动 PostgreSQL
    sudo /usr/pgsql-${postgresql_Version}/bin/postgresql-${postgresql_Version}-setup initdb
    sudo systemctl enable postgresql-${postgresql_Version}
    sudo systemctl start postgresql-${postgresql_Version}

    # 安装 PostgreSQL 插件
    rm -rf /www/panel/plugins/Postgresql
    mkdir /www/panel/plugins/Postgresql
    wget -O /www/panel/plugins/Postgresql/postgresql.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=postgresql"
    cd /www/panel/plugins/Postgresql
    unzip -o postgresql.zip && rm -rf postgresql.zip
    # 写入插件安装状态
    panel writePluginInstall postgresql
}

Uninstall_PostgreSQL() {
    # 停止 PostgreSQL
    systemctl stop postgresql${postgresql_Version}-server
    systemctl disable postgresql${postgresql_Version}-server
    # 删除 PostgreSQL
    dnf remove postgresql${postgresql_Version}-server -y
    # 删除插件
    rm -rf /www/panel/plugins/Postgresql
    panel writePluginUnInstall postgresql
}

Update_PostgreSQL() {
    # 停止 PostgreSQL
    systemctl stop postgresql${postgresql_Version}-server
    # 更新 PostgreSQL
    dnf update postgresql${postgresql_Version}-server -y
    # 启动 PostgreSQL
    systemctl start postgresql${postgresql_Version}-server
    # 更新插件
    rm -rf /www/panel/plugins/Postgresql
    mkdir /www/panel/plugins/Postgresql
    wget -O /www/panel/plugins/Postgresql/postgresql.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=postgresql"
    cd /www/panel/plugins/Postgresql
    unzip -o postgresql.zip && rm -rf postgresql.zip
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
