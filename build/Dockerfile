FROM python:3.6.9
MAINTAINER RobertLC
LABEL description="pysatools_heroku_build"

# Install required system packages and remove the apt packages cache when done.
RUN apt-get update && \
    apt-get upgrade -y && \ 	
    apt-get install -y \
	git \
	p7zip-full \
	ssh \
	nginx \
	gettext-base \
	supervisor \
    nano  && \
    apt-get clean

# Install npm and node.js and phantomjs for bokeh
RUN git clone https://github.com/nvm-sh/nvm.git && \
    echo 'source /nvm/nvm.sh' >> ~/.bashrc && \
    /bin/bash --login -c "nvm install 10.16.0" && \
    /bin/bash --login -c "npm install -g npm@latest" && \
	wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 && \
    tar jxvf phantomjs-2.1.1-linux-x86_64.tar.bz2 -C /usr/local/share/ && \
    ln -s /usr/local/share/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin/ && \
    rm phantomjs-2.1.1-linux-x86_64.tar.bz2

# Install python packages
COPY requirements.txt /var/
RUN pip install --no-cache-dir -r /var/requirements.txt 

# Add web code which include : webcode, nginx_template.conf, uwsgi.ini, uwsgi_params, supervisord.conf	
ADD pysaweb /home/pysaweb/

# Setting pysaweb_nginx.conf and supervisord.conf 
RUN ln -s /home/pysaweb/pysaweb_nginx.conf /etc/nginx/sites-enabled/ && \
    ln -s /home/pysaweb/pysaweb_nginx.conf /etc/nginx/sites-available/ && \
    rm -f /etc/nginx/sites-available/default && \ 
    rm -f /etc/nginx/sites-enabled/default && \
    cp /home/pysaweb/supervisord.conf /etc/supervisor/conf.d/supervisord.conf && \	
	mkdir /var/run/uwsgi
	
# Copy this Dockerfile for record purpose 
COPY Dockerfile /home/pysaweb/

# Run the init.sh, it will do
# -source nvm 
# -envsubst the env PORT to nginx.conf form nginx_template.conf
# -start Supervisor which start Nginx and uWSGI 
ADD init.sh /home/pysaweb/init.sh
CMD bash /home/pysaweb/init.sh

