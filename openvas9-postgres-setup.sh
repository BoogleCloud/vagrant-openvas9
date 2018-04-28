#!/bin/bash
#
# This script will attempt to download and install Openvas9 from source
#
# Check for root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 
	exit 1
fi
# Check for pre-requisites
#
apt-get -y install sshpass firewalld smbclient nmap dpkg-dev pkg-config libssh-dev libgnutls28-dev libglib2.0-dev libpcap-dev libgpgme11-dev uuid-dev bison libksba-dev libhiredis-dev libsnmp-dev libgcrypt20-dev libldap2-dev libmicrohttpd-dev libxml2-dev libxslt1-dev libsqlite3-dev libpq-dev g++ cmake  gcc-mingw-w64 libgnutls28-dev perl-base heimdal-dev heimdal-multidev libpopt-dev libglib2.0-dev xmltoman doxygen xsltproc Gettext python-polib python-setuptools python-paramiko redis-server sqlite3 gnutls-bin rpm nsis alien postgresql postgresql-contrib postgresql-server-dev-9.4

if [ ! -d ~/openvas9 ]; then
	mkdir -p ~/openvas9
fi
cd ~/openvas9

# Check for the packages and download
if [ ! -f openvas-libraries-9.0.*.tar.gz ]; then
	wget https://github.com/greenbone/gvm-libs/releases/download/v9.0.2/openvas-libraries-9.0.2.tar.gz
fi

if [ ! -f v5.1.*.tar.gz ]; then
	wget https://github.com/greenbone/openvas-scanner/archive/v5.1.2.tar.gz
fi

if [ ! -f openvas-manager-7.0.*.tar.gz ]; then
	wget https://github.com/greenbone/gvm/releases/download/v7.0.3/openvas-manager-7.0.3.tar.gz
fi

if [ ! -f v7.0.*.tar.gz ]; then
	wget https://github.com/greenbone/gsa/archive/v7.0.3.tar.gz
fi

if [ ! -f 1.3.*.tar.gz ]; then
    wget https://github.com/greenbone/gvm-tools/archive/1.3.1.tar.gz
fi

if [ ! -f openvas-cli-1.4.*.tar.gz ]; then
	wget http://wald.intevation.org/frs/download.php/2397/openvas-cli-1.4.5.tar.gz
fi

if [ ! -f v1.0.*.tar.gz ]; then
	wget https://github.com/greenbone/openvas-smb/archive/v1.0.3.tar.gz
fi

if [ ! -f ospd-1.2.*.tar.gz ]; then
	wget http://wald.intevation.org/frs/download.php/2401/ospd-1.2.0.tar.gz
fi


# Extract
tar xf openvas-libraries-9.0.*.tar.gz
tar xf v5.1.*.tar.gz
tar xf openvas-manager-7.0.*.tar.gz
tar xf v7.0.*.tar.gz
tar xf openvas-cli-1.4.*.tar.gz
tar xf v1.0.*.tar.gz
tar xf ospd-1.2.*.tar.gz

# Ready to build
# Fix gsad_js-fr typo in gsa-7.0.3 (should be removed in a future release)
sed -i '430s/msgid/msgstr/' gsa-7.0.3/src/po/gsad_js-fr.po

# Build and Install (with all defaults)
CMAKE_OPTS="-DBACKEND=POSTGRESQL"
cd gvm-libs-*
mkdir build
cd build
cmake ..
make
make doc
make install
make rebuild_cache
cd ../..

cd openvas-smb*
mkdir build
cd build
cmake ..
make
make install
make rebuild_cache
cd ../..

cd openvas-scanner*
mkdir build
cd build
cmake ..
make
make doc
make install
make rebuild_cache
cd ../..

cd openvas-cli*
mkdir build
cd build
cmake ..
make
make doc
make install
make rebuild_cache
cd ../..

cd gvm-7*
mkdir build
cd build
cmake .. $CMAKE_OPTS
make
make doc
make install
make rebuild_cache
cd ../..

cd gsa-7*
mkdir build
cd build
cmake ..
make
make doc
make install
make rebuild_cache
cd ../..


# Final setup
# Make sure there is an openvas user and group
if [ ! $(id -u openvas) ]; then
	adduser openvas --system --home /home/openvas --shell /bin/bash --disabled-password -q
	groupadd openvas
fi

# Set up Postgres User and DB
sudo -u postgres createuser -DRS openvas
sudo -u postgres createdb -O openvas tasks
sudo -u postgres psql tasks -c 'create role dba with superuser noinherit;'
sudo -u postgres psql tasks -c 'grant dba to openvas;'
sudo -u postgres psql tasks -c 'create extension "uuid-ossp";'

# Set up redis
cp -f /usr/local/share/doc/openvas-scanner/example_redis_2_6.conf /etc/redis/redis.conf
systemctl restart redis-server

# For better performance (and fewer out-of-memory crashes), redis likes this option
echo vm.overcommit_memory=1 >> /etc/sysctl.conf

ldconfig
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --add-service http
firewall-cmd --add-service https
firewall-cmd --add-service http --permanent
firewall-cmd --add-service https --permanent

# Initial Openvas Setup, these steps can take a while
/usr/local/bin/openvas-manage-certs -a
/usr/local/sbin/greenbone-nvt-sync
chown -R openvas /usr/local
sudo -u openvas /usr/local/sbin/greenbone-certdata-sync
sudo -u openvas /usr/local/sbin/greenbone-scapdata-sync
/usr/local/sbin/openvassd -C

# Create necessary files for openvas service structure
# Starting with greenbone security v7.0.3 we need to add an appropriate HTTP host header to allow remote connetions
# We can find the current system hostname with "/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'"
PREFIX=/usr/local
mkdir -p $PREFIX/lib/systemd/system
cat > $PREFIX/lib/systemd/system/openvas-scanner.service << scannerservice
[Unit]
Description=OpenVAS Scanner
After=network.target
Before=openvas-manager.service

[Service]
Type=forking
EnvironmentFile=-$PREFIX/etc/sysconfig/openvas-scanner
ExecStart=$PREFIX/sbin/openvassd --listen-owner=openvas --listen-group=openvas
Restart=always
RestartSec=1
User=root
Group=root
TimeoutSec=300

[Install]
WantedBy=multi-user.target
scannerservice


cat > $PREFIX/lib/systemd/system/openvas-manager.service << managerservice
[Unit]
Description=OpenVAS Manager
After=network.target
After=openvas-scanner.service
After=postgresql.service
Before=gsad.service

[Service]
Type=forking
EnvironmentFile=-$PREFIX/etc/sysconfig/openvas-manager
ExecStart=$PREFIX/sbin/openvasmd --listen 127.0.0.1 --port 9390 --max-ips-per-target=65536 --max-email-attachment-size=20971520 --max-email-include-size=2097152
Restart=always
RestartSec=1
User=openvas
Group=openvas
TimeoutSec=300

[Install]
WantedBy=multi-user.target
managerservice


cat > $PREFIX/lib/systemd/system/gsad.service << gsadservice
[Unit]
Description=Greenbone Security Assistant
After=network.target
After=openvas-scanner.service
After=openvas-manager.service

[Service]
Type=forking
EnvironmentFile=-$PREFIX/etc/sysconfig/gsad
ExecStart=$PREFIX/sbin/gsad --allow-header-host "openvas" --listen 0.0.0.0 --port 443 --mlisten 127.0.0.1 --mport 9390 --timeout 60 --rport=80
Restart=always
RestartSec=1
User=openvas
Group=openvas
TimeoutSec=300

[Install]
WantedBy=multi-user.target
gsadservice

# Symlink it all
ln -s $PREFIX/lib/systemd/system/openvas-scanner.service /etc/systemd/system/multi-user.target.wants
ln -s $PREFIX/lib/systemd/system/openvas-manager.service /etc/systemd/system/multi-user.target.wants
ln -s $PREFIX/lib/systemd/system/gsad.service /etc/systemd/system/multi-user.target.wants

# Allow greenbone to bind to a privileged port
setcap 'cap_net_bind_service=+ep' /usr/local/sbin/gsad

# Reload systemd and check it out
systemctl daemon-reload
systemctl start openvas-scanner
systemctl start openvas-manager
systemctl start gsad


# Install the update script. Add the following line (without leading #) to the root crontab if you want to run it daily
# 0 14 * * 1-5 /usr/local/sbin/openvas-update.sh 2>&1 /tmp/openvas-update.log
cat > $PREFIX/sbin/openvas-update.sh << updatetask
#!/bin/bash
#
$PREFIX/sbin/greenbone-nvt-sync
sudo -u openvas $PREFIX/sbin/greenbone-scapdata-sync
sudo -u openvas $PREFIX/sbin/greenbone-certdata-sync
updatetask


# Grab the check setup and test it (as of 4/2018 this doesn't work with the postgres backend)
#cd /usr/local/sbin
#wget --no-check-certificate https://svn.wald.intevation.org/svn/openvas/trunk/tools/openvas-check-setup
#chmod +x openvas-check-setup*
#openvas-check-setup --v9
