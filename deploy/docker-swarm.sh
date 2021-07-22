#!/bin/bash

# 命名空间
namepsace=yxkj
root_dir=/home/$namepsace
mkdir -p $root_dir

#### api镜像处理 start ####
service_api=hyperf-skeleton
volume_api=$root_dir/$service_api
if [ ! -d  $volume_api  ]
then
    echo "首次克隆项目代码..."
    cd $root_dir
    git clone https://hub.fastgit.org/cdwxw/$service_api.git
else
    echo "拉取最新项目代码..."
    cd $volume_api
    git pull https://hub.fastgit.org/cdwxw/$service_api.git
fi
volume_root=$volume_api/deploy
echo "挂载根路径... $volume_root"
# mkdir -p $volume_root
if [ ! -d  $volume_root  ]
then
    echo "挂载根路径不存在... $volume_root"
    exit 255
fi
echo "api镜像处理... $volume_api"
cd $volume_api
# docker build -t 569529989/$service_api:latest .
# docker push 569529989/$service_api:latest
#### api镜像处理 end ####

#### nginx镜像处理 start ####
service_nginx=nginx_prod
volume_nginx=$volume_root/$service_nginx
mkdir -p $volume_nginx/log
mkdir -p $volume_nginx/dist
echo "nginx镜像处理... $volume_nginx"
cd $volume_nginx
# docker build -t 569529989/$service_nginx:1.19.2 .
# docker push 569529989/$service_nginx:1.19.2
#### nginx镜像处理 end ####

#### mysql镜像处理 start ####
service_mysql=mysql_master_prod
volume_mysql=$volume_root/$service_mysql
mkdir -p $volume_mysql
echo "mysql镜像处理... $volume_mysql"
# chmod 755 $volume_mysql/mysqld.cnf
#### mysql镜像处理 end ####

#### redis镜像处理 start ####
service_redis=redis_prod
volume_redis=$volume_root/$service_redis
mkdir -p $volume_redis
echo "redis镜像处理... $volume_redis"
#### redis镜像处理 end ####

#### 部署swarm集群 start ####
echo "编写docker-compose.yml ..."
cd $volume_root
cat << EOF > $volume_root/stack.yml
version: "3.9"
services:
  $service_api:
    image: 569529989/$service_api:latest
    # image: 192.168.205.10:5000/hyperf:latest
    ports:
      - 9501:9501
    depends_on:
      - $service_mysql
      - $service_redis
    entrypoint: ["php", "/opt/www/bin/hyperf.php", "start"]
    networks:
      - net_back_prod
    deploy:
      mode: replicated
      replicas: 2
  $service_nginx:
    image: 569529989/$service_nginx:1.19.2
    # image: 192.168.205.10:5000/nginx:1.19.2
    ports:
      - 80:80
      - 28888:28888
      - 29999:29999
      - 28080:28080
      - 29501:29501
    # volumes:
      # - /etc/localtime:/etc/localtime:ro
      # - $volume_nginx/nginx.conf:/etc/nginx/nginx.conf
      # - $volume_nginx/log:/var/log/nginx
      # - $volume_nginx/dist:/usr/share/nginx/html:ro
    networks:
      - net_back_prod
    deploy:
      mode: replicated
      replicas: 2
      placement:
        constraints:
          - "node.role==manager"
  $service_mysql:
    image: mysql:5.7
    # image: 192.168.205.10:5000/mysql:5.7
    ports:
      - 3306:3306
    # volumes:
      # - $volume_mysql/mysql:/var/lib/mysql
      # - $volume_mysql/mysqld.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf
    environment:
      MYSQL_ROOT_PASSWORD: mysql!@#MYSQL
      MYSQL_DATABASE: cntz_big_screen
      MYSQL_USER: yxkj
      MYSQL_PASSWORD: 123qwe!@#
    networks:
      - net_back_prod
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - "node.hostname==swarm-manager"
  $service_redis:
    image: redis:6.2.2
    # image: 192.168.205.10:5000/redis:6.2.2
    ports:
      - 6379:6379
    command: redis-server --requirepass redis!@#REDIS --appendonly yes
    sysctls:
      - net.core.somaxconn=4096
    # volumes:
      # - $volume_redis/data:/data
    environment:
      - TZ=Asia/Shanghai
      - LANG=en_US.UTF-8
    networks:
      - net_back_prod
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - "node.hostname==swarm-manager"
  phpmyadmin_prod:
    image: phpmyadmin:5.0.2
    # image: 192.168.205.10:5000/phpmyadmin:5.0.2
    ports:
      - 8888:80
    environment:
      - PMA_HOST=$service_mysql
    networks:
      - net_back_prod
    deploy:
      mode: replicated
      replicas: 1
  phpredisadmin_prod:
    image: erikdubbelboer/phpredisadmin:v1.13.2
    # image: 192.168.205.10:5000/phpredisadmin:v1.13.2
    ports:
      - 9999:80
    environment:
      - REDIS_1_HOST=$service_redis
      - REDIS_1_AUTH=redis!@#REDIS
      - ADMIN_USER=yxkj
      - ADMIN_PASS=123qwe!@#
    networks:
      - net_back_prod
    deploy:
      mode: replicated
      replicas: 1
  visualizer_prod:
    image: dockersamples/visualizer:stable
    # image: 192.168.205.10:5000/visualizer:stable
    ports:
      - 8080:8080
    stop_grace_period: 1m30s
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    deploy:
      mode: replicated
      replicas: 1
networks:
  net_front_prod:
  net_back_prod:
EOF

echo "部署swarm集群 ..."
docker node ls
docker stack deploy $namepsace -c stack.yml
echo "docker service ls"
docker service ls
echo "docker stack ps $namepsace"
docker stack ps $namepsace
# docker stack rm yxkj
#### 部署swarm集群 end ####