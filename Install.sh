#!/bin/bash

# Script de instalación de Odoo 18 en Ubuntu 24.04 LTS

# Salir inmediatamente si un comando falla
set -e

# Solicitar la contraseña para el usuario de PostgreSQL
read -s -p "Ingresa la contraseña para el usuario de PostgreSQL 'odoo18': " DB_PASSWORD
echo

echo "Actualizando el servidor..."
sudo apt-get update
sudo apt-get upgrade -y

echo "Instalando y configurando medidas de seguridad..."
sudo apt-get install -y openssh-server fail2ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

echo "Instalando paquetes y librerías requeridas..."
sudo apt-get install -y python3-pip python3-dev libxml2-dev libxslt1-dev zlib1g-dev \
libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libjpeg-dev libpq-dev \
liblcms2-dev libblas-dev libatlas-base-dev npm node-less git python3-venv

echo "Instalando Node.js y NPM..."
sudo apt-get install -y nodejs npm

if [ ! -f /usr/bin/node ]; then
    echo "Creando enlace simbólico para node..."
    sudo ln -s /usr/bin/nodejs /usr/bin/node
fi

echo "Instalando less y less-plugin-clean-css..."
sudo npm install -g less less-plugin-clean-css

echo "Instalando PostgreSQL..."
sudo apt-get install -y postgresql

echo "Creando usuario de PostgreSQL para Odoo..."
sudo -u postgres psql -c "CREATE USER odoo18 WITH CREATEDB SUPERUSER PASSWORD '$DB_PASSWORD';"

echo "Creando usuario de sistema para Odoo..."
sudo adduser --system --home=/opt/odoo18 --group odoo18

echo "Clonando Odoo 18 desde GitHub..."
sudo -u odoo18 -H git clone --depth 1 --branch master --single-branch https://www.github.com/odoo/odoo /opt/odoo18/

echo "Creando entorno virtual de Python..."
sudo -u odoo18 -H python3 -m venv /opt/odoo18/venv

echo "Instalando paquetes Python requeridos..."
sudo -u odoo18 -H /opt/odoo18/venv/bin/pip install wheel
sudo -u odoo18 -H /opt/odoo18/venv/bin/pip install -r /opt/odoo18/requirements.txt

echo "Instalando wkhtmltopdf..."
sudo apt-get install -y xfonts-75dpi
sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb -O /tmp/wkhtmltox.deb
sudo dpkg -i /tmp/wkhtmltox.deb || true
sudo apt-get -f install -y

echo "Configurando el archivo de configuración de Odoo..."
sudo mkdir -p /etc/odoo
sudo bash -c "cat > /etc/odoo/odoo.conf <<EOF
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo18
db_password = $DB_PASSWORD
addons_path = /opt/odoo18/addons
logfile = /var/log/odoo/odoo18.log
EOF"

sudo chown odoo18: /etc/odoo/odoo.conf
sudo chmod 640 /etc/odoo/odoo.conf

echo "Creando directorio de logs..."
sudo mkdir -p /var/log/odoo
sudo chown odoo18:root /var/log/odoo

echo "Configurando el servicio systemd para Odoo..."
sudo bash -c 'cat > /etc/systemd/system/odoo18.service <<EOF
[Unit]
Description=Odoo18
Documentation=http://www.odoo.com
[Service]
Type=simple
User=odoo18
ExecStart=/opt/odoo18/venv/bin/python /opt/odoo18/odoo-bin -c /etc/odoo/odoo.conf
[Install]
WantedBy=multi-user.target
EOF'

sudo chmod 755 /etc/systemd/system/odoo18.service
sudo chown root: /etc/systemd/system/odoo18.service

echo "Iniciando y habilitando el servicio de Odoo..."
sudo systemctl daemon-reload
sudo systemctl start odoo18.service
sudo systemctl enable odoo18.service

echo "La instalación de Odoo 18 ha finalizado. Puedes acceder a través de http://<tu_dominio_o_IP>:8069"
