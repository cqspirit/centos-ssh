# =============================================================================
# jdeathe/centos-ssh
#
# CentOS-6 6.7 x86_64 / EPEL/IUS Repos. / OpenSSH / Supervisor.
# 
# =============================================================================
FROM centos:centos6.7

MAINTAINER jdeathe & Ge Yong <geyongnus@gmail.com>

# -----------------------------------------------------------------------------
# Import the RPM GPG keys and install Repositories
# -----------------------------------------------------------------------------
RUN rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-6 \
	&& rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6 \
	&& rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm \
	&& rpm --import https://dl.iuscommunity.org/pub/ius/IUS-COMMUNITY-GPG-KEY \
	&& rpm -Uvh https://dl.iuscommunity.org/pub/ius/stable/CentOS/6/x86_64/ius-release-1.0-14.ius.centos6.noarch.rpm

# -----------------------------------------------------------------------------
# Base Install
# -----------------------------------------------------------------------------
RUN yum -y install \
	vim-minimal-7.4.629-5.el6 \
	sudo-1.8.6p3-20.el6_7 \
	openssh-5.3p1-112.el6_7 \
	openssh-server-5.3p1-112.el6_7 \
	openssh-clients-5.3p1-112.el6_7 \
	python-pip-7.1.0-1.el6 \
	yum-plugin-versionlock-1.1.30-30.el6 \
	&& yum versionlock add \
	vim-minimal \
	sudo \
	openssh \
	openssh-server \
	openssh-clients \
	python-pip \
	yum-plugin-versionlock \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Install supervisord (required to run more than a single process in a container)
# Note: EPEL package lacks /usr/bin/pidproxy
# We require supervisor-stdout to allow output of services started by 
# supervisord to be easily inspected with "docker logs".
# -----------------------------------------------------------------------------
RUN pip install --upgrade 'pip == 1.4.1' \
	&& pip install --upgrade 'supervisor == 3.1.3' 'supervisor-stdout == 0.1.1' \
	&& mkdir -p /var/log/supervisor/

# -----------------------------------------------------------------------------
# UTC Timezone & Networking
# -----------------------------------------------------------------------------
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
	&& echo "NETWORKING=yes" > /etc/sysconfig/network

# -----------------------------------------------------------------------------
# Configure SSH for non-root public key authentication
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's/^UsePAM yes/#UsePAM yes/g' \
	-e 's/^#UsePAM no/UsePAM no/g' \
	-e 's/^PasswordAuthentication yes/PasswordAuthentication no/g' \
	-e 's/^#PermitRootLogin yes/PermitRootLogin no/g' \
	-e 's/^#UseDNS yes/UseDNS no/g' \
	/etc/ssh/sshd_config

# -----------------------------------------------------------------------------
# Enable the wheel sudoers group
# -----------------------------------------------------------------------------
RUN sed -i 's/^# %wheel\tALL=(ALL)\tALL/%wheel\tALL=(ALL)\tALL/g' /etc/sudoers

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD etc/ssh-bootstrap /etc/
ADD etc/services-config/ssh/authorized_keys /etc/services-config/ssh/
ADD etc/services-config/ssh/sshd_config /etc/services-config/ssh/
ADD etc/services-config/ssh/ssh-bootstrap.conf /etc/services-config/ssh/
ADD etc/services-config/supervisor/supervisord.conf /etc/services-config/supervisor/

RUN chmod 600 /etc/services-config/ssh/sshd_config \
	&& chmod +x /etc/ssh-bootstrap \
	&& ln -sf /etc/services-config/supervisor/supervisord.conf /etc/supervisord.conf \
	&& ln -sf /etc/services-config/ssh/sshd_config /etc/ssh/sshd_config \
	&& ln -sf /etc/services-config/ssh/ssh-bootstrap.conf /etc/ssh-bootstrap.conf

# -----------------------------------------------------------------------------
# Purge
# -----------------------------------------------------------------------------
RUN rm -rf /etc/ld.so.cache \ 
	; rm -rf /sbin/sln \
	; rm -rf /usr/{{lib,share}/locale,share/{man,doc,info,gnome/help,cracklib,il8n},{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
	; rm -rf /var/cache/{ldconfig,yum}/* \
	; > /etc/sysconfig/i18n

EXPOSE 22

# add cralwer
ENV CRAW_USER  dc-agent
ENV CRAW_PW crawler_next

RUN useradd $CRAW_USER -M -p $CRAW_PW

RUN \
  yum groupinstall -y development && \
  yum install -y zlib-dev openssl-devel sqlite-devel bzip2-devel wget curl && \
  yum install -y xz-libs vim expect && \
  yum install -y gcc gcc-c++ make flex bison gperf ruby  openssl-devel freetype-devel && \
  yum install -y fontconfig-devel libicu-devel sqlite-devel libpng-devel libjpeg-devel && \
  yum install -y tar python-devel libxml2 libxml2-dev libxslt* zlib openssl -y && \
  yum clean all

RUN \
   cd /tmp &&rm -rf Python-2.7.6.tar.xz && \
   wget http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tar.xz && \
   xz -d Python-2.7.6.tar.xz && \
   tar -xvf Python-2.7.6.tar && \
   cd Python-2.7.6 && \
   ./configure --prefix=/usr/local && \
   make && make install
   
RUN \
  cd /tmp && \
  wget --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz && \
  tar -xvf setuptools-1.4.2.tar.gz && \
  cd setuptools-1.4.2 && \
  python setup.py install
  
ADD etc/crawl /etc/crawl

RUN \
  curl https://raw.githubusercontent.com/pypa/pip/master/contrib/get-pip.py | python - && \
  pip install virtualenv && \
  cd /etc/crawl/  && \
  pip install -r manager-requirement.txt && \
  pip install -r agent-requirement.txt
  
# 
RUN cd /usr/bin && \
    wget http://soft.6eimg.com/phantomjs && \
    chmod a+x phantomjs
#RUN \
#   cd /tmp && \
#   git clone --recursive git://github.com/ariya/phantomjs.git && \
#   cd phantomjs && ./build.py && \
#   chmod a+x ./bin/phantomjs && \
#   cp ./bin/phantomjs /usr/bin/ 
   
RUN \
   rm -rf /tmp/*
   
RUN \
   rm -rf /usr/bin/python && \
   ln -s /usr/local/bin/python2.7 /usr/bin/python  && \
   sed -i 's|#!/usr/bin/python|#!/usr/bin/python2.6|g' /usr/bin/yum
# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV SSH_USER_PASSWORD "6estates!Usw"
ENV SSH_USER "6estates"
ENV SSH_USER_HOME_DIR "/home/6estates"
RUN mkdir -p /etc/supervisord.d
ADD etc/services-config/supervisor/supervisord.d/*.conf /etc/supervisord.d/
# - add log path

#VOLUME ["/opt/crawl", "/opt/crawl"] 
#VOLUME ["/public/log", "/var/log"] 

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
