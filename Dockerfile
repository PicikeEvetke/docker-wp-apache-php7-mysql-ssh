# Wordpress 4.7.1 alap telepítés
FROM ubuntu
MAINTAINER Szivós Tamás <szivos.tamas@it-droid.hu>
LABEL Description="Wordpress 4.7.1 alap telepítése apache2, php7.0, mysql, ssh és supervisor csomagokkal" Vendor="Adalon Solutions Kft." Version="1.0"

# Néhány előkészület a telepítéshez
RUN dpkg-divert --local --rename --add /sbin/initctl 
RUN ln -sf /bin/true /sbin/initctl 
RUN mkdir -p /var/run/sshd 
RUN mkdir -p /var/lock/apache2
RUN mkdir -p /var/run/apache2
RUN mkdir -p /var/tmp
RUN mkdir -p /var/log/supervisor

# Környezeti változók beállítása
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV TERM dumb

# Aptitude repo beállítása
RUN echo "deb http://archive.ubuntu.com/ubuntu xenial main universe" > /etc/apt/sources.list
RUN rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Alkalmazások telepítése (apache2,php7.0,mariadb10.0,ssh,supervisor)
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install pwgen python-setuptools curl git nano sudo unzip openssh-server openssl
RUN apt-get -y install mysql-server mysql-client supervisor apache2 libapache2-mod-php7.0 php7.0-fpm php7.0

# Wordpress követelmények telepítése
RUN apt-get -y install php7.0-mysql php7.0-curl php7.0-gd php7.0-intl php-pear php7.0-imap php7.0-mcrypt php7.0-ps php7.0-pspell php7.0-recode php7.0-snmp php7.0-sqlite php7.0-tidy php7.0-xmlrpc php7.0-xsl

# SSH login fix. Hogy ne dobjon ki azonnal bejelentkezéskor
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
RUN sed -i "s/PermitRootLogin without-password/PermitRootLogin yes/" /etc/ssh/sshd_config

# MySQL beállítása
RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/explicit_defaults_for_timestamp = true\nbind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

# Wordpress virtualhost felmásolása
COPY wordpress.apache2.conf /etc/apache2/sites-available/wordpress.conf
RUN a2dissite 000-default
RUN a2ensite wordpress
RUN a2enmod rewrite expires

# Eltávolítjuk az apache kezdőlapot
RUN rm /var/www/html/index.html

# Supervisor beállítása
RUN /usr/bin/easy_install supervisor
RUN /usr/bin/easy_install supervisor-stdout
ADD ./supervisord.apache2.conf /etc/supervisord.conf

# Rendszer felhasználó létrehozása a Wordpress számára
RUN useradd -m -d /home/wordpress -p $(openssl passwd -1 'wordpress') -G root -s /bin/bash wordpress \
    && usermod -a -G www-data wordpress \
    && usermod -a -G sudo wordpress \
    && ln -s /var/www /home/wordpress/www

# Legfrissebb Wordpress telepítése
ADD http://wordpress.org/latest.tar.gz /var/tmp/latest.tar.gz
RUN cd /var/tmp/ \
    && tar xvf latest.tar.gz \
    && rm latest.tar.gz

RUN mv /var/tmp/wordpress/* /var/www \
    && chown -R wordpress:www-data /var/www \
    && chmod -R 775 /var/www

# Wordpress inicializálás és indítás
ADD ./start.apache2.sh /start.sh
RUN chmod 755 /start.sh

# aptitude tisztítása
RUN apt-get clean
RUN rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# VOLUME meghatározása
VOLUME ["/var/lib/mysql", "/var/www", "/var/run/sshd"]
WORKDIR /var/www

# portmappek beállítása
EXPOSE 9011 3306 80 22

# Supervisord elindítása
CMD ["/bin/bash", "/start.sh"]
