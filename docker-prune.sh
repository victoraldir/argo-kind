#!/bin/zsh



# Docker prune script
docker rm -vf $(docker ps -aq)
docker rmi -f $(docker images -q)
docker system prune -a --volumes