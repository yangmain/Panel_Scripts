#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1"        # 操作
mysql_Version="$2" # MySQL版本

download_Url="https://dl.panel.haozi.xyz"                               # 下载节点
setup_Path="/www"                                                       # 面板安装目录
mysql_Path="${setup_Path}/server/mysql"                                 # MySQL目录
os_Version=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\.?.*/\1/') # 系统版本
ipLocation=$(curl -s https://api.panel.haozi.xyz/api/ip/getIpLocation)  # 获取IP位置

cpuCore=$(cat /proc/cpuinfo | grep "processor" | wc -l) # CPU核心数

Download_MySQL() {
    # 准备安装目录
    rm -rf ${mysql_Path}
    mkdir -p ${mysql_Path}
    cd ${mysql_Path}

    dnf module disable mysql -y
    # 判断位置是否是中国
    if [[ ${ipLocation} == "中国" ]]; then
        rpm -Uvh http://mirrors.ustc.edu.cn/mysql-repo/mysql${mysql_Version}-community-release-el${os_Version}.rpm
        sed -i 's@repo.mysql.com@mirrors.ustc.edu.cn/mysql-repo@g' /etc/yum.repos.d/mysql-community.repo
    else
        rpm -Uvh http://repo.mysql.com/mysql${mysql_Version}-community-release-el${os_Version}.rpm
    fi
    dnf install mysql-community-server -y
    # 检查是否安装成功
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：MySQL安装失败，请截图错误信息寻求帮助。"
        exit 1
    fi
}

Install_MySQL() {
    # 写入my.cnf
    cat >/etc/my.cnf <<EOF
[client]
#password = your_password
port = 3306
socket = /tmp/mysql.sock

[mysqld]
port = 3306
socket = /tmp/mysql.sock
datadir = ${mysql_Path}
default_storage_engine = InnoDB
skip-external-locking
key_buffer_size = 8M
max_allowed_packet = 1G
table_open_cache = 32
sort_buffer_size = 256K
net_buffer_length = 4K
read_buffer_size = 128K
read_rnd_buffer_size = 256K
myisam_sort_buffer_size = 4M
thread_cache_size = 4
tmp_table_size = 8M

#skip-name-resolve
max_connections = 500
max_connect_errors = 100
open_files_limit = 65535

log-bin = mysql-bin
binlog_format = mixed
server-id = 1
slow_query_log = 1
slow-query-log-file = ${mysql_Path}/mysql-slow.log
long_query_time = 3
#log_queries_not_using_indexes = on
log-error = ${mysql_Path}/mysql-error.log

innodb_data_home_dir = ${mysql_Path}
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = ${mysql_Path}
innodb_buffer_pool_size = 16M
innodb_redo_log_capacity = 5M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 500M

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout
EOF

    # 调整配置
    sed -i '/server-id/a\binlog_expire_logs_seconds = 600000' /etc/my.cnf
    sed -i '/tmp_table_size/a\lower_case_table_names = 1' /etc/my.cnf
    sed -i '/skip-external-locking/i\table_definition_cache = 400' /etc/my.cnf
    sed -i '/table_definition_cache/i\performance_schema_max_table_instances = 400' /etc/my.cnf
    sed -i '/innodb_lock_wait_timeout/a\innodb_max_dirty_pages_pct = 90' /etc/my.cnf
    sed -i '/innodb_max_dirty_pages_pct/a\innodb_read_io_threads = 4' /etc/my.cnf
    sed -i '/innodb_read_io_threads/a\innodb_write_io_threads = 4' /etc/my.cnf
    sed -i '/#log_queries_not_using_indexes/a\early-plugin-load = ""' /etc/my.cnf
    sed -i '/#skip-name-resolve/i\explicit_defaults_for_timestamp = true' /etc/my.cnf

    # 根据CPU核心数确定写入线程数
    sed -i 's/innodb_write_io_threads = 4/innodb_write_io_threads = '${cpuCore}'/g' /etc/my.cnf
    sed -i 's/innodb_read_io_threads = 4/innodb_read_io_threads = '${cpuCore}'/g' /etc/my.cnf

    # 根据内存大小调参
    mem_Total=$(free -m | grep Mem | awk '{print  $2}')
    if [[ ${mem_Total} -gt 1024 && ${mem_Total} -lt 2048 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 128#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 768K#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 16#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 32M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = 64M" /etc/my.cnf
        sed -i "s#^innodb_log_buffer_size.*#innodb_log_buffer_size = 16M#" /etc/my.cnf
    elif [[ ${mem_Total} -ge 2048 && ${mem_Total} -lt 4096 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 256#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 1M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 32#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = 128M#" /etc/my.cnf
        sed -i "s#^innodb_log_buffer_size.*#innodb_log_buffer_size = 32M#" /etc/my.cnf
    elif [[ ${mem_Total} -ge 4096 && ${mem_Total} -lt 8192 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 512#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 2M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 32M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 64#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 64M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = 256M#" /etc/my.cnf
        sed -i "s#^innodb_log_buffer_size.*#innodb_log_buffer_size = 64M#" /etc/my.cnf
    elif [[ ${mem_Total} -ge 8192 && ${mem_Total} -lt 16384 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 1024#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 4M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 64M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 128#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 128M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 1024M#" /etc/my.cnf
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = 512M#" /etc/my.cnf
        sed -i "s#^innodb_log_buffer_size.*#innodb_log_buffer_size = 128M#" /etc/my.cnf
    elif [[ ${mem_Total} -ge 16384 && ${mem_Total} -lt 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 512M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 2048#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 8M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 128M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 256#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 256M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 2048M#" /etc/my.cnf
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = 1G#" /etc/my.cnf
        sed -i "s#^innodb_log_buffer_size.*#innodb_log_buffer_size = 256M#" /etc/my.cnf
    elif [[ ${mem_Total} -ge 32768 ]]; then
        sed -i "s#^key_buffer_size.*#key_buffer_size = 1024M#" /etc/my.cnf
        sed -i "s#^table_open_cache.*#table_open_cache = 4096#" /etc/my.cnf
        sed -i "s#^sort_buffer_size.*#sort_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^read_buffer_size.*#read_buffer_size = 16M#" /etc/my.cnf
        sed -i "s#^myisam_sort_buffer_size.*#myisam_sort_buffer_size = 256M#" /etc/my.cnf
        sed -i "s#^thread_cache_size.*#thread_cache_size = 512#" /etc/my.cnf
        sed -i "s#^tmp_table_size.*#tmp_table_size = 512M#" /etc/my.cnf
        sed -i "s#^innodb_buffer_pool_size.*#innodb_buffer_pool_size = 4096M#" /etc/my.cnf
        sed -i "s#^innodb_redo_log_capacity.*#innodb_redo_log_capacity = 2G#" /etc/my.cnf
        sed -i "s#^innodb_log_buffer_size.*#innodb_log_buffer_size = 512M#" /etc/my.cnf
    fi

    # 为my.cnf设置644权限
    chmod 644 /etc/my.cnf

    chown -R mysql:mysql ${mysql_Path}
    chgrp -R mysql ${mysql_Path}/.
    chmod -R 755 ${mysql_Path}

    # 修改初始化路径
    sed -i "s@ExecStartPre=/usr/bin/mysqld_pre_systemd@ExecStartPre=/usr/bin/mysqld_pre_systemd --user=mysql --basedir=/www/server/mysql --datadir=/www/server/mysql@g" /usr/lib/systemd/system/mysqld.service
    sed -i "s@ExecStartPre=+/usr/bin/mysqld_pre_systemd@ExecStartPre=+/usr/bin/mysqld_pre_systemd --user=mysql --basedir=/www/server/mysql --datadir=/www/server/mysql@g" /usr/lib/systemd/system/mysqld.service
    systemctl daemon-reload

    cd ${mysql_Path}

    # 启动mysql
    systemctl enable mysqld
    systemctl start mysqld
    mysqlPassword=$(grep 'temporary password' ${mysql_Path}/mysql-error.log | awk -F ": " '{print $2}') # MySQL默认密码
    mysqlNewPassword="HaoZi!@#0123$(cat /dev/urandom | head -n 16 | md5sum | head -c 20)"               # MySQL新密码
    echo "MySQL临时root密码："${mysqlPassword}
    mysql --connect-expired-password -uroot -p$mysqlPassword -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlNewPassword}';"
    mysql --connect-expired-password -uroot -p$mysqlNewPassword -e "drop database test"
    mysql --connect-expired-password -uroot -p$mysqlNewPassword -e "delete from mysql.user where user='';"
    mysql --connect-expired-password -uroot -p$mysqlNewPassword -e "flush privileges;"
    echo "MySQL初始root密码："${mysqlNewPassword}
    panel writeMysqlPassword ${mysqlNewPassword}
    systemctl restart mysqld

    # 安装 MySQL 插件
    rm -rf /www/panel/plugins/Mysql
    mkdir /www/panel/plugins/Mysql
    wget -O /www/panel/plugins/Mysql/mysql.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=mysql"
    cd /www/panel/plugins/Mysql
    unzip -o mysql.zip && rm -rf mysql.zip
    # 写入插件安装状态
    panel writePluginInstall mysql
}

Uninstall_MySQL() {
    # 停止mysql
    systemctl stop mysqld
    systemctl disable mysqld
    # 删除mysql
    dnf remove mysql-community-server -y
    # 删除插件
    rm -rf /www/panel/plugins/Mysql
    panel writePluginUnInstall mysql
}

Update_MySQL() {
    # 停止mysql
    systemctl stop mysqld
    # 更新mysql
    dnf update mysql-community-server -y
    # 启动mysql
    systemctl start mysqld
    # 更新插件
    #mysqlPluginVersion = $(wget -qO- -t1 -T2 "https://api.panel.haozi.xyz/api/plugin/version?slug=mysql")
    #mysqlPluginUrl = $(wget -qO- -t1 -T2 "https://api.panel.haozi.xyz/api/plugin/url?slug=mysql")
    rm -rf /www/panel/plugins/Mysql
    mkdir /www/panel/plugins/Mysql
    wget -O /www/panel/plugins/Mysql/mysql.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=mysql"
    cd /www/panel/plugins/Mysql
    unzip -o mysql.zip && rm -rf mysql.zip
}

if [ "$action" == 'install' ]; then
    Download_MySQL
    Install_MySQL
fi
if [ "$action" == 'uninstall' ]; then
    Uninstall_MySQL
fi
if [ "$action" == 'update' ]; then
    Update_MySQL
fi
