#!/bin/bash
shopt -s expand_aliases
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
. /etc/profile

HR="+----------------------------------------------------"

action="$1" # 操作

Install() {
    dnf install fail2ban -y
    # 检查是否安装成功
    if [ "$?" != "0" ]; then
        echo -e $HR
        echo "错误：fail2ban安装失败，请截图错误信息寻求帮助。"
        exit 1
    fi
    # 修改 fail2ban 配置文件
    sed -i 's!# logtarget.*!logtarget = /var/log/fail2ban.log!' /etc/fail2ban/fail2ban.conf
    sed -i 's!logtarget\s*=.*!logtarget = /var/log/fail2ban.log!' /etc/fail2ban/jail.conf
    cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 600
findtime = 300
maxretry = 5
banaction = firewallcmd-ipset
action = %(action_mwl)s

# ssh-START
[ssh]
enabled = true
filter = sshd
port = 22
maxretry = 5
findtime = 300
bantime = 86400
action = %(action_mwl)s
logpath = /var/log/secure
# ssh-END

# pure-ftpd-START
[pure-ftpd]
enabled = true
filter = pure-ftpd
port = 21
maxretry = 5
findtime = 300
bantime = 86400
action = %(action_mwl)s
logpath = /var/log/messages
# pure-ftpd-END
EOF
    # 替换端口
    sshPort=$(cat /etc/ssh/sshd_config | grep 'Port ' | awk '{print $2}')
    if [ "${sshPort}" == "" ]; then
        sshPort="22"
    fi
    sed -i "s/port = 22/port = ${sshPort}/g" /etc/fail2ban/jail.local
    if [ -f "/etc/pure-ftpd/pure-ftpd.conf" ]; then
        ftpPort=$(cat /etc/pure-ftpd/pure-ftpd.conf | grep "Bind" | awk '{print $2}' | awk -F "," '{print $2}')
    fi
    if [ "${ftpPort}" == "" ]; then
        ftpPort="21"
        sed -i "s/port = 21/port = ${ftpPort}/g" /etc/fail2ban/jail.local
    else
        sed -i "s/port = 21/port = ${ftpPort}/g" /etc/fail2ban/jail.local
    fi
    # 启动 fail2ban
    systemctl unmask fail2ban
    systemctl daemon-reload
    systemctl enable fail2ban
    systemctl restart fail2ban

    # 安装 fail2ban 插件
    rm -rf /www/panel/plugins/Fail2ban
    mkdir /www/panel/plugins/Fail2ban
    wget -O /www/panel/plugins/Fail2ban/fail2ban.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=fail2ban"
    cd /www/panel/plugins/Fail2ban
    unzip -o fail2ban.zip && rm -rf fail2ban.zip
    # 写入插件安装状态
    panel writePluginInstall fail2ban
}

Uninstall() {
    # 停止 fail2ban
    systemctl stop fail2ban
    systemctl disable fail2ban
    # 删除 fail2ban
    dnf remove fail2ban -y
    # 删除插件
    rm -rf /www/panel/plugins/Fail2ban
    panel writePluginUnInstall fail2ban
    # 删除配置目录
    rm -rf /etc/fail2ban
}

Update() {
    # 停止 fail2ban
    systemctl stop fail2ban
    # 更新 fail2ban
    dnf update fail2ban -y
    # 启动 fail2ban
    systemctl start fail2ban
    # 更新插件
    rm -rf /www/panel/plugins/Fail2ban
    mkdir /www/panel/plugins/Fail2ban
    wget -O /www/panel/plugins/Fail2ban/fail2ban.zip "https://api.panel.haozi.xyz/api/plugin/url?slug=fail2ban"
    cd /www/panel/plugins/Fail2ban
    unzip -o fail2ban.zip && rm -rf fail2ban.zip
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
