#!/bin/bash

# 获取docker 服务 ip
docker_ip() {
    docker inspect --format '{{.NetworkSettings.Networks.yxkj_net_swarm_prod.IPAddress}}' "$@"
}

CONTAINER_NAME=`docker ps | grep mysql_slave_prod | awk '{print $12}'`
CONTAINER_IP=$(docker_ip $CONTAINER_NAME)
echo $CONTAINER_IP