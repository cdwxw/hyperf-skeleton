#!/bin/bash

# my.cnf不能是755权限，会导致mysql容器忽略global write配置文件
# chmod 755 $volume_mysql_master/my.cnf

# swarm集群容器不可使用 docker restart $CONTAINER_ID，会导致重启多个同名容器，swarm集群在容器重启过程中判定掉线自动再重启一个新容器
# docker exec $CONTAINER_ID bash -c "echo 'log-bin=/var/lib/mysql/mysql-bin' >> /etc/mysql/mysql.conf.d/mysqld.cnf"
# docker exec $CONTAINER_ID bash -c "echo 'server-id=100' >> /etc/mysql/mysql.conf.d/mysqld.cnf"

# 获取docker容器ip
docker_ip() {
    docker inspect --format '{{.NetworkSettings.Networks.yxkj_net_swarm_prod.IPAddress}}' "$@"
}

docker ps

# 获取mysql容器id和ip
CONTAINER_ID=`docker ps | grep '_mysql_' | awk '{print $1}'`
CONTAINER_IP=$(docker_ip $CONTAINER_ID)
echo $CONTAINER_ID
echo $CONTAINER_IP

# 连接主库
until docker exec -it $CONTAINER_ID bash -c 'export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e ";"'
do
    echo "Waiting for $CONTAINER_ID database connection..."
    sleep 4
done

# 获取主库当前的pos
MS_STATUS=`docker exec $CONTAINER_ID sh -c 'export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e "SHOW MASTER STATUS;"'`
CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`
echo $CURRENT_LOG
echo $CURRENT_POS

# 从库执行以下命令，开启IO线程监听主库的binlog文件
# change master to master_host='mysql-1',master_user='slave',master_password='123456',master_log_file='mysql-bin.000003',master_log_pos=3825,master_port=3306;
start_slave_stmt="STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='$CONTAINER_IP',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
# start_slave_stmt="START SLAVE;"
start_slave_cmd='export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e "'
start_slave_cmd+="$start_slave_stmt"
start_slave_cmd+='"'
echo $start_slave_cmd

# docker exec -it $CONTAINER_ID sh

# cat << EOF > start_slave_stmt.sh
# docker exec $CONTAINER_ID sh -c '$start_slave_cmd'
# EOF

# 展示最终结果
docker exec $CONTAINER_ID sh -c "export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e 'SHOW MASTER STATUS \G;'"
docker exec $CONTAINER_ID sh -c "export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e 'SHOW SLAVE STATUS \G;'"

change_master="export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e \"STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='"
change_master+="$CONTAINER_IP"
change_master+="',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL';\""
# echo $change_master







# 参考方法
start() {
docker exec mysql_master bash -c 'export MYSQL_PWD=mysql!@#MYSQL; mysqldump -uroot --master-data=1 --single-transaction --routines --all-databases > /var/lib/mysql/master.sql'
cp /root/v3_mysqldocker/mysql-master-slave-config/master/data/master.sql /root/v3_mysqldocker/mysql-master-slave-config/slave/data/master.sql
change_master="export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e \"STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='"
change_ip="$(docker-ip mysql_master)"
change_master+="$change_ip"
change_master+="',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL';\""

echo $change_master

# tart_slave_stmt="START SLAVE;"
# start_slave_cmd='export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e "'
# start_slave_cmd+="$start_slave_stmt"
# start_slave_cmd+='"'

# docker exec mysql_slave bash -c "export MYSQL_PWD=mysql!@#MYSQL; mysql -uroot -e 'STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL';'"
docker exec mysql_slave bash -c "$change_master"
# start_slave_stmt="STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL';"
docker exec mysql_slave bash -c "export MYSQL_PWD=mysql!@#MYSQL; mysql -uroot < /var/lib/mysql/master.sql"

# 配置主从复制
# start_slave_stmt="STOP SLAVE; RESET SLAVE; CHANGE MASTER TO MASTER_HOST='$(docker-ip mysql_master)',MASTER_USER='root',MASTER_PASSWORD='mysql!@#MYSQL',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave_stmt="START SLAVE;"
start_slave_cmd='export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e "'
start_slave_cmd+="$start_slave_stmt"
start_slave_cmd+='"'
docker exec mysql_slave sh -c "$start_slave_cmd"

# 展示最终结果
docker exec mysql_master sh -c "export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e 'SHOW MASTER STATUS \G'"
docker exec mysql_slave sh -c "export MYSQL_PWD=mysql!@#MYSQL; mysql -u root -e 'SHOW SLAVE STATUS \G'"
}