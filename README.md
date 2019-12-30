# **HerokuDockerDjangoNginxUwsgi-SingleContainer-Example**

Docker image with uWSGI, Nginx, and Django (python3.6) in a single container and deploy to Heroku. 

Last update : 20191231<br/><br/>



## 簡介

主要說明如何在單一容器中執行 Nginx+uWSGI+Django，然後以 Dockerfile 部署到 Heroku。基本上，大部分的 Nginx 及 uWSGI 設定可以直接參考 uwsgi 的官方說明 :

- [Setting up Django and your web server with uWSGI and nginx](https://uwsgi-docs.readthedocs.io/en/latest/tutorials/Django_and_nginx.html) 
- [Running python webapps on Heroku with uWSGI](https://uwsgi-docs.readthedocs.io/en/latest/tutorials/heroku_python.html) 

但是因為 Heroku，關於 PORT 設定、server 啟動方式以及 Dockerfile 撰寫，這些都是比較 tricky 的部分，所以接下來將綜合官方文件、網路查到的資訊及個人經驗，說明如何完成這些設定及部署。



## 教學

### 事前準備 

- Docker base image : eg. python 3.6.9

- Django project :  eg.  pysaweb  ( it will ADD to /home  when docker image be created )
- Blank file ( put in pysaweb directory )
  - Nginx  file :  **pysaweb_nginx_template.conf** 、**uwsgi_params**
  - uWSGI  file : **pysaweb_uwsgi.ini**
  - supervisor file : **supervisord.conf**

------

### 設定 Nginx

- **pysaweb_nginx_template.conf** 

  ```bash
  # the upstream component nginx needs to connect to 
  upstream django {    
  	server unix:///var/run/uwsgi/pysaweb_unixsock.sock; 
  }
  
  # configuration of the server
  server {
      # the port your site will be served on
  	listen ${PORT};      
  	
      # the domain name or IP it will serve for
      server_name 0.0.0.0; 
      charset     utf-8;
      
      # max upload size
      client_max_body_size 75M;
  
      # Django media or your data
      location /data  {
          alias /home/pysaweb/temp_data;  # your Django project's media files - amend as required
      }
      location /static {
          alias /home/pysaweb/pysa/static; # your Django project's static files - amend as required
      }
  
      # Finally, send all non-media requests to the Django server.
      location / {
          uwsgi_pass  django;
          include     /home/pysaweb/uwsgi_params; # the uwsgi_params file you installed
      }
  }
  ```

  - Nginx 與  uwsgi 之間使用 Unix sockets ，會由 uwsgi 生成 file socket 文件，所以路徑就保持與 uwsgi.ini 一致即可，然後因為檔案權限問題，路徑須設在 /tmp 或是 /var/run 中，nginx 和 uwsgi 才能有辦法對 file socket 操作，777 的設定也才能有效。
  - upstream 後接的 django 只是變數名稱，可自行改成其他變數名。
  - `listen ${PORT};` 是 nginx 取得 heroku PORT 的關鍵，`${PORT}` 作為 placeholder，在容器啟動過程中，使用 `envsubst` 指令將環境變數 PORT 值填入，再轉存為 nginx 真正讀取的設定檔 **pysaweb_nginx.conf** 。
  - Location 的 /media 及 /static ，建議參照專案的 settings.py 及 url.py 做設定，如果要更改實體路徑，那就必須在 settings.py 中額外加入 STATIC_ROOT 參數，然後執行 python  manage.py collectstatic 。
  - Location 的 / ， uwsgi_pass 後接的名稱要與 upstream 中的一致， 在這裡也就是 django ，而  include 後接的路徑就是接下來要提到的 **uwsgi_params** 文件。

- **uwsgi_params** 

  ```
  uwsgi_param  QUERY_STRING       $query_string;
  uwsgi_param  REQUEST_METHOD     $request_method;
  uwsgi_param  CONTENT_TYPE       $content_type;
  uwsgi_param  CONTENT_LENGTH     $content_length;
  
  uwsgi_param  REQUEST_URI        $request_uri;
  uwsgi_param  PATH_INFO          $document_uri;
  uwsgi_param  DOCUMENT_ROOT      $document_root;
  uwsgi_param  SERVER_PROTOCOL    $server_protocol;
  uwsgi_param  REQUEST_SCHEME     $scheme;
  uwsgi_param  HTTPS              $https if_not_empty;
  
  uwsgi_param  REMOTE_ADDR        $remote_addr;
  uwsgi_param  REMOTE_PORT        $remote_port;
  uwsgi_param  SERVER_PORT        $server_port;
  uwsgi_param  SERVER_NAME        $server_name;
  
  # copy from https://github.com/nginx/nginx/blob/master/conf/uwsgi_params
  ```

  - 這文件內容固定就這樣，不用做任何更改 。

------

### uWSGI 設定

- **pysaweb_uwsgi.ini**

  ```bash
  [uwsgi]
  # the base directory (django-related full path)
  chdir           = /home/pysaweb
  
  # the socket (use the full path )
  socket          = /var/run/uwsgi/pysaweb_unixsock.sock
  chmod-socket    = 777
  
  # Django's wsgi file
  module          = mysite.wsgi
  
  # process-related settings
  master          = true
  
  # maximum number of worker processes
  processes       = 4
  threads = 8 
  
  # clear environment on exit
  vacuum          = true
  
  # Heroku-required options
  die-on-term = true
  memory-report = true
  
  #harakiri = 90 # respawn processes taking more than 90 seconds
  #max-requests = 5000 # respawn processes after serving 5000 requests
  ```

  - 依據 django project 做設定。

  - socket 就像之前說的因為權限問題，除了給予最高的 777 ，路徑也必須設在那，這可以避免出現下方 error

    ```
    bind(): No such file or directory [core/socket.c line 230]
    ```

  - processes 及 treads ，[uwsgi 官方文件](https://uwsgi-docs.readthedocs.io/en/latest/tutorials/heroku_python.html)說 : 
  
    > It obviosuly depend on your app. But as we are on a memory-limited environment you can expect better memory usage with threads. In addition to this, if you plan to put production-apps on Heroku be sure to understand how Dynos and their proxy works (it is very important. really)

  - die-on-term 及 memory-report，[uwsgi 官方文件](https://uwsgi-docs.readthedocs.io/en/latest/tutorials/heroku_python.html)說 : 
  
    > The second one (–die-on-term) is required to change the default behaviour of uWSGI when it receive a SIGTERM (brutal reload, while Heroku expect a shutdown). The memory-report option (as we are in a memory constrained environment) is a good thing.
  

------

### supervisor 設定

使用 supervisor 的目的是為了解決 Nginx 及 uWSGI 在 single container 中的啟動問題，尤其是在 Heroku 上只有這個方法能行。原本在本地端 run container 時可以用下面指令啟動服務 : 

```bash
/etc/init.d/nginx start # do not use nginx -g 'daemon off;'
uwsgi --ini /home/pysaweb/pysaweb_uwsgi.ini
```

但這方式在 Heroku 上不成功，確切原因不知道，後來經過一些測試，發現使用 supervisor 就都可以在本地、Heroku 上順利執行服務。  

- **supervisord.conf**

  ```bash
  [supervisord]
  nodaemon=true
  
  [program:uwsgi]
  command=/usr/local/bin/uwsgi --ini /home/pysaweb/pysaweb_uwsgi.ini
  # In heroku, the stdout or stderr is captured into your logs.
  loglevel=debug 
  stdout_logfile=/dev/stdout
  stdout_logfile_maxbytes=0
  stderr_logfile=/dev/stderr
  stderr_logfile_maxbytes=0
  
  [program:nginx]
  command=nginx -g 'daemon off;'
  loglevel=debug
  stdout_logfile=/dev/stdout
  stdout_logfile_maxbytes=0
  stderr_logfile=/dev/stderr
  stderr_logfile_maxbytes=0
  # Graceful stop, see http://nginx.org/en/docs/control.html
  stopsignal=QUIT
  ```

  - 把 logfile 訊息全轉成 `/dev/stdout` 輸出，因為 Heroku 會抓取 stdout & stderr 輸出到 Heroku  logs 。使用 stdout 時，logfile_maxbytes 必須為 0 。

  - Nginx 的啟動指令要使用 `nginx -g 'daemon off;'` 。

  - 可參考  http://supervisord.org/configuration.html

    https://github.com/tiangolo/uwsgi-nginx-docker/blob/master/python3.6/supervisord.conf

------

### Dockerfile 製作

這部分會創建 **Dockerfile** 及 **init.sh**，**init.sh** 為 container 啟動時要執行的指令稿，也就是 CMD 要執行的項目。

- **Dockerfile**

  ```bash
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
  
  # Install npm and node.js and phantomjs for python package bokeh
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
  
  # Run the init.sh
  ADD init.sh /home/pysaweb/init.sh
  CMD bash /home/pysaweb/init.sh
  ```

  - 首先安裝套件，其中 nginx、gettext-base ( envsubst 指令用到 )、 supervisor、 nano 為必裝。
  - 如果 django project 沒有使用到 bokeh，則跳過安裝 node.js 等套件。
  - 安裝 python packages，requirements.txt 中必須有 uwsgi 。
  - 將 django project (pysaweb) 添加到 /home 目錄底下。
  - 接下來是重點，要處理 nginx 、uwsgi、supervisord 的文件配置，首先將 **pysaweb_nginx.conf** soft-link 到 `/etc/nginx/sites-enabled/` 及 `/etc/nginx/sites-available/` ，然後強制刪除這兩個目錄底下的 default ，這樣就能避免一些問題，例如 port 80 、permission denied 等問題。接下來是將 **supervisord.conf** 複製到  `/etc/supervisor/conf.d/supervisord.conf` ，最後是創建 file socket 存放的目錄。
  - **pysaweb_nginx.conf** 這文件會在 container 啟動時，經由  **init.sh** 以 **pysaweb_nginx_template.conf**  為模板而創建，為了獲取正確的 Heroku PORT。
  - 最後是設定 container 的啟動指令，就是執行 **init.sh**。

- **init.sh**

  ```bash
  #!/bin/bash
  # source /nvm/nvm.sh  
  envsubst < /home/pysaweb/pysaweb_nginx_template.conf >  /home/pysaweb/pysaweb_nginx.conf
  rm -f /etc/nginx/sites-available/default
  rm -f /etc/nginx/sites-enabled/default 
  exec /usr/bin/supervisord
  ```
  
  - 使用 `envsubst` 將 Heroku PORT 填入 template.conf ，輸出到 nginx.conf。
  - 再次執行強制刪除 nginx 的 default 文件，因為根據測試的結果，部署到 Heroku 後，default 仍然在那，這就是比較奇怪的地方，所以這裡就在執行一次。
  - 最後啟動 supervisord ，它會將 Nginx 和 uWSGI 啟動為它的子程序。

------

## 總結 & 補充

以上就是關於如何製作可在 Heroku 上以單一容器執行 Nginx+uWSGI+Django 的 Docker Image。

此外，這裡還有些資源可參考 :

- https://github.com/tiangolo/uwsgi-nginx-docker/tree/master/python3.6
- https://myapollo.com.tw/zh-tw/linux-command-envsubst/

當然如果不執著於單一容器，通常會將 Nginx 放在另一個容器執行，用 docker-compose 管理，這方面可參考 : 

- https://github.com/twtrubiks/docker-django-nginx-uwsgi-postgres-tutorial/blob/master/README.md
- https://github.com/rjoonas/heroku-docker-nginx-example
- https://stackoverflow.com/questions/49147389/heroku-docker-port-environment-variable-in-nginx

<br/><br/>