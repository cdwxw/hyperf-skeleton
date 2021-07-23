#!/bin/bash

# my.cnf不能是755权限，会导致mysql容器忽略global write配置文件
# chmod 755 $volume_mysql_master/my.cnf

# 获取docker 服务 ip
docker_ip() {
    docker inspect --format '{{.NetworkSettings.Networks.yxkj_net_swarm_prod.IPAddress}}' "$@"
}

CONTAINER_ID=`docker ps | grep 'mysql_master_prod' | awk '{print $1}'`
CONTAINER_IP=$(docker_ip $CONTAINER_ID)
echo $CONTAINER_ID
echo $CONTAINER_IP

show_master="export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e \"show master status;\""
echo $show_master

change_master="export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e \"STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='"
change_master+="$CONTAINER_IP"
change_master+="',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL';\""
echo $change_master


# docker exec $CONTAINER_ID bash -c "echo 'log-bin=/var/lib/mysql/mysql-bin' >> /etc/mysql/mysql.conf.d/mysqld.cnf"
# docker exec $CONTAINER_ID bash -c "echo 'server-id=100' >> /etc/mysql/mysql.conf.d/mysqld.cnf"
# swarm集群容器不可使用 docker restart，会导致重启多个同名容器，swarm集群在容器重启过程中判定掉线自动再重启一个新容器
# docker restart $CONTAINER_ID

echo "docker exec -it $CONTAINER_ID bash"
docker ps