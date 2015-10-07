#!/bin/bash
########################################################################
# 
# Created on Sun, 17:05 16 August 2015
# By Sucipto.net
#
# Changelog
# * Add mysql_secure_installation
# * Change Password
# * Silent yum
########################################################################

VERSION=2.0.3

# Function setup Hostname
function setup_hostname {
	NEWHOSTNAME=CHIP$RANDOM
	
	echo "Mengubah Hostname Menajadi $NEWHOSTNAME"
	hostname $NEWHOSTNAME
	cat > "/etc/sysconfig/network"<<END
NETWORKING=yes
HOSTNAME=$NEWHOSTNAME
END
}

# Cleanup FUnction
function setup_clean {
	yum -y -q remove httpd postfix mysql-server mysql-client 
}

# Random Password Function 
function get_password() {
	# Check whether our local salt is present.
	SALT=/var/lib/radom_salt
	if [ ! -f "$SALT" ]
	then
		head -c 512 /dev/urandom > "$SALT"
		chmod 400 "$SALT"
	fi
	password=`(cat "$SALT"; echo $1) | md5sum | base64`
	echo ${password:0:13}
}

function setup_mariadb {
	
	cat > /etc/yum.repos.d/MariaDB.repo<<END

# MariaDB 10.0 CentOS repository list - created 2015-08-16 05:18 UTC
# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.0/centos6-x86
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
END

yum -y -q install MariaDB-server MariaDB-client
	
	# Set Tweak
	cat > /etc/my.cnf.d/chipt-weak.cnf <<END
# These values override values from /etc/my.cnf

[mysqld]
key_buffer = 12M
query_cache_limit = 256K
query_cache_size = 4M

init_connect='SET collation_connection = utf8_unicode_ci'
init_connect='SET NAMES utf8' 
character-set-server = utf8 
collation-server = utf8_unicode_ci 
skip-character-set-client-handshake

default_tmp_storage_engine = MyISAM 
default_storage_engine = MyISAM
skip-innodb

#log-slow-queries=/var/log/mysql/slow-queries.log  --- error in newer versions of mysql

[client]
default-character-set = utf8
END
	# Start MariaDB
	service mysql start
	
	# Set Password
	passwd=`get_password`
	mysqladmin -u root password "$passwd"
    
    # Also change root password
    echo -e "$passwd\n$passwd\n" | passwd 2>/dev/null
	
	# Secure install (unattended)
	echo -e "$passwd\nn\nY\nY\nY\nY\n" | mysql_secure_installation 2>/dev/null
	cat > ~/.my.cnf <<END
[client]
user = root
password = $passwd
END
    # Make temp pass
    cat > /tmp/pass.tmp <<END
$passwd
END
	chmod 600 ~/.my.cnf
	
	# Upgrade MariaDB
	mysql_upgrade
}

# Install php dan keperluanya
function setup_lainya {
    rpm -ivh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    yum -y -q update
	yum install -y -q php-curl php-cli php-mcrypt php-gd php-mbstring php-xml php-common unzip vim crontabs curl htop wget
    
    #Flush iptables
    iptables -F
    iptables-save
}

function setup_ajenti {
	#curl https://raw.githubusercontent.com/ajenti/ajenti/1.x/scripts/install-rhel.sh | sh
    #wget -q http://repo.ajenti.org/ajenti-repo-1.0-1.noarch.rpm  -O /tmp/ajenti.rpm
    
    rpm -ivh http://repo.ajenti.org/ajenti-repo-1.0-1.noarch.rpm
    yum install ajenti -y -q
    #rpm -i /tmp/ajenti.rpm
	yum install -y -q ajenti-v ajenti-v-nginx ajenti-v-mysql ajenti-v-php-fpm php-mysql ajenti-v-ftp-pureftpd php-curl php-cli php-mcrypt php-gd unzip vim crontabs
	
    # Backup ajenti config
    mv /etc/ajenti/config.json /etc/ajenti/config.json.bak
    
    # Create preconfigured config
    
    cat > "/etc/ajenti/config.json"<<END
{
    "users": {
        "root": {
            "configs": {
                "ajenti.plugins.notepad.notepad.Notepad": "{\"bookmarks\": [], \"root\": \"/\"}", 
                "ajenti.plugins.terminal.main.Terminals": "{\"shell\": \"sh -c $SHELL || bash\"}", 
                "ajenti.users.UserManager": "{\"sync-provider\": \"\"}", 
                "ajenti.plugins.logs.main.Logs": "{\"root\": \"/var/log\"}", 
                "ajenti.plugins.mysql.api.MySQLDB": "{\"password\": \"mysql_password_here\", \"user\": \"root\", \"hostname\": \"localhost\"}", 
                "ajenti.plugins.fm.fm.FileManager": "{\"start\": \"/srv\", \"new_owner\": \"www-data\", \"root\": \"/\", \"new_group\": \"www-data\"}", 
                "ajenti.plugins.dashboard.dash.Dash": "{\"widgets\": [{\"index\": 0, \"config\": null, \"container\": \"1\", \"class\": \"ajenti.plugins.sensors.memory.MemoryWidget\"}, {\"index\": 1, \"config\": null, \"container\": \"1\", \"class\": \"ajenti.plugins.sensors.memory.SwapWidget\"}, {\"index\": 2, \"config\": {\"device\": \"/\"}, \"container\": \"1\", \"class\": \"ajenti.plugins.fstab.widget.DiskSpaceWidget\"}, {\"index\": 3, \"config\": {\"device\": \"/\"}, \"container\": \"1\", \"class\": \"ajenti.plugins.fstab.widget.DiskFreeSpaceWidget\"}, {\"index\": 4, \"config\": null, \"container\": \"1\", \"class\": \"ajenti.plugins.sensors.load.LoadWidget\"}, {\"index\": 0, \"config\": {\"text\": \"<h3 style='text-align: center'>Selamat Datang di Panel VPS</h3><br/> Untuk Bantuan, silakan mebaca panduan di <a target='_blank' href='http://lapak.sucipto.net/doc'>http://lapak.sucipto.net/doc</a>\"}, \"container\": \"0\", \"class\": \"ajenti.plugins.dashboard.text.TextWidget\"}, {\"index\": 1, \"config\": null, \"container\": \"0\", \"class\": \"ajenti.plugins.sensors.uptime.UptimeWidget\"}, {\"index\": 2, \"config\": null, \"container\": \"0\", \"class\": \"ajenti.plugins.power.power.PowerWidget\"}, {\"index\": 3, \"config\": null, \"container\": \"0\", \"class\": \"ajenti.plugins.sensors.cpu.CPUWidget\"}]}", 
                "ajenti.plugins.tasks.manager.TaskManager": "{\"task_definitions\": []}"
            }, 
            "password": "sha512|\$6\$rounds=40000\$nIVrqqz638rB8wOo\$VbMv8y2lStgcsYxEuu7JfHiEd06eeiSoIbg7Hvivj9K1vPayaCbAiAqtpyOoIkNfIXFmMD0jK6Dd4WFnvywkY1", 
            "permissions": []
        }
    }, 
    "language": "", 
    "bind": {
        "host": "0.0.0.0", 
        "port": 8000
    }, 
    "enable_feedback": true, 
    "ssl": {
        "enable": true, 
        "certificate_path": "/etc/ajenti/ajenti.pem"
    }, 
    "authentication": true, 
    "installation_id": 156847
}
END
    
    # Configure mysql plugin for ajenti
    mysql_pass=`cat /tmp/pass.tmp`
    sed -i "s/mysql_password_here/$mysql_pass/" /etc/ajenti/config.json
    
    service ajenti restart
}

function setup_swap {
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
	sysctl vm.swappiness=10
	sysctl vm.vfs_cache_pressure=50
	cat > /etc/sysctl.conf <<END
# Chip Swap Tweak
vm.swappiness=10
vm.vfs_cache_pressure = 50
END
}


########################################################################
# BEGIN STARTUP SCRIPT AJENTI INSTALLATION
########################################################################
clear
echo "================================================================================"
echo " Wellcome to Chip Engine VPS auto Install for CentOS 6"
echo " This script will install the following software :"
echo "      * Ajenti Panel"
echo "      * Ajenti V for Hosting"
echo "      * 2GB SWAP"
echo "      * Nginx, PHP-FPM, MariaDB"
echo "      * Some Tweak"
echo "      * Love <3"
echo " Copyright (c) 2015 by Sucipto.Net"
echo " Visit : http://sucipto.net"
echo "================================================================================"

# 1. Change hostname
echo "[*] Setup Hostname"
if [ `hostname` == 'vultr.guest' ]; then
    setup_hostname
    echo "[OK]   Done"
else
    echo "[SKIP]    Hostname not touched"
fi
# 2. Clean up the software
echo "[*] Cleanup The Server"
setup_clean
echo "[OK]   Done"
# 3. Setup MariaDB
echo "[*] Setup Mariadb"
setup_mariadb
echo "[OK]   Done"
# 4. Setup Keprluan lainya
echo "[*]Setup Lainya"
setup_lainya
echo "[OK]   Done"
# 5. Setup Ajenti + Ajenti V
echo "[*]Setup AJenti"
setup_ajenti
echo "[OK]   Done"
# 6. SWAP Tweak
echo "[*] Setup SWAP"
setup_swap
echo "[OK]   Done"
# 8. Username dan Password MySQL
echo "[*] Generate Installation file"
MY_IP=`curl -s ipinfo.io/ip`
MY_PASS=`cat /tmp/pass.tmp`
cat > ~/setup_info.txt <<END
# Installasi Selesai #
Berikut ini detail informasi VPS anda.

Ajenti Panel
------------
URL     : https://$MY_IP:8000
User    : root
Pass    : $MY_PASS

SSH Access
------------
IP      : $MY_IP
Port    : 22
User    : root
Pass    : $MY_PASS

Apabila ada kesulitan, silakan mengunjungi halaman dokumentasi kami di
Dokumentasi : http://goo.gl/SmeBnZ
Contoh Installasi Wordpress : http://goo.gl/UtGY9K
Contoh Setting DNS di Cloudflare : http://goo.gl/l2K6VA

END
rm /tmp/pass.tmp
echo "[OK]   Done"
echo "------------------------------------------------------"
# tambah size
sed -i 's/max_execution_time = 30/max_execution_time = 600/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 35M/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 20M/g' /etc/php.ini
cat ~/setup_info.txt

