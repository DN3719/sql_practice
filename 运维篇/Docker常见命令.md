# Docker 常用命令速查

> 运维篇笔记，按日常使用频率整理。命令格式：`docker [对象] [操作]`。

## 1. 镜像管理

```bash
docker search mysql              # 搜索镜像
docker pull mysql:8.0            # 拉取镜像
docker images                    # 查看本地镜像列表
docker images | grep mysql       # 过滤查看
docker tag mysql:8.0 mymysql:8   # 打标签
docker rmi mysql:8.0             # 删除镜像（先删引用它的容器）
docker rmi $(docker images -q)   # 删除所有镜像（谨慎）
docker history mysql:8.0         # 查看镜像构建历史
docker image inspect mysql:8.0   # 查看镜像详细信息
```

## 2. 容器生命周期

```bash
docker run -d --name mymysql -p 3306:3306 mysql:8.0   # 后台运行并映射端口
docker run -it --rm ubuntu bash                       # 前台交互运行，退出即删
docker ps                        # 查看运行中的容器
docker ps -a                     # 查看所有容器（含已退出）
docker ps -a --filter name=mysql # 按名字过滤
docker start mymysql             # 启动已存在的容器
docker stop mymysql              # 优雅停止（发 SIGTERM）
docker restart mymysql           # 重启
docker kill mymysql              # 强制停止（发 SIGKILL）
docker pause mymysql             # 暂停容器内进程
docker unpause mymysql           # 恢复暂停
docker rm mymysql                # 删除容器
docker rm -f mymysql             # 强制删除运行中的容器
docker rm $(docker ps -aq)       # 删除所有已停止容器（谨慎）
docker rename mymysql mysql1     # 容器重命名
```

`docker run` 常用参数：

| 参数 | 作用 |
| --- | --- |
| `-d` | 后台运行 |
| `-it` | 交互式 + 分配终端 |
| `--name` | 指定容器名 |
| `-p 主机端口:容器端口` | 端口映射 |
| `-v 主机路径:容器路径` | 数据卷挂载 |
| `--network` | 指定网络 |
| `--restart=always` | 开机/崩溃自动重启 |
| `-e` | 设置环境变量 |
| `--rm` | 容器退出后自动删除 |

## 3. 进入容器与执行命令

```bash
docker exec -it mymysql bash     # 进入容器执行 bash（最常用）
docker exec mymysql mysql -uroot -p   # 直接在容器内执行命令
docker attach mymysql            # 附着到容器主进程（不推荐，会占用主进程）
docker cp 本地文件 mymysql:/tmp/       # 复制文件进容器
docker cp mymysql:/var/log/mysql.log ./ # 从容器复制文件出来
docker top mymysql               # 查看容器内进程
docker stats                     # 实时查看容器资源占用
```

## 4. 日志

```bash
docker logs mymysql              # 查看全部日志
docker logs -f mymysql           # 实时跟踪日志（类似 tail -f）
docker logs --tail 100 mymysql   # 只看最后 100 行
docker logs --since 10m mymysql  # 看最近 10 分钟的日志
docker logs mymysql 2>&1 | grep ERROR   # 过滤错误日志
```

## 5. 网络

```bash
docker network ls                # 查看网络列表（bridge/host/none）
docker network create mynet      # 创建自定义网络
docker network inspect mynet     # 查看网络详情和已连接容器
docker network connect mynet mysql1   # 把容器连到网络
docker network disconnect mynet mysql1 # 断开
docker network rm mynet          # 删除网络
```

> 自定义网络（bridge）里的容器可以用**容器名互相访问**，主从复制里 `slave1` 连主库时经常这么用，比写死 IP 更稳定。

## 6. 数据卷

```bash
docker volume ls                 # 查看数据卷列表
docker volume create mydata      # 创建数据卷
docker volume inspect mydata     # 查看数据卷详情
docker volume rm mydata          # 删除数据卷

# 挂载方式一：匿名/具名卷（由 Docker 管理，删除容器数据不丢）
docker run -d -v mydata:/var/lib/mysql mysql:8.0

# 挂载方式二：绑定挂载（把宿主机目录直接挂进去）
docker run -d -v /data/mysql:/var/lib/mysql mysql:8.0

# 挂载方式三：--mount 语法（推荐，语义更清晰）
docker run -d --mount type=bind,source=/data/mysql,target=/var/lib/mysql mysql:8.0
```

> 生产环境 MySQL 容器一定要挂载数据目录，否则 `docker rm` 后数据就没了。

## 7. 资源限制

```bash
docker run -d --memory="1g" --cpus="2" mysql:8.0    # 限制内存 1G、CPU 2 核
docker update --memory="2g" mymysql                 # 修改运行中容器限制
```

## 8. 系统与清理

```bash
docker version                  # 查看版本信息
docker info                     # 查看 Docker 整体状态
docker system df                # 查看磁盘占用（镜像/容器/卷/构建缓存）
docker system prune             # 清理停止的容器、无用网络、悬空镜像和构建缓存
docker system prune -a          # 更彻底：连未使用的镜像一起删（谨慎）
docker container prune          # 只删已停止容器
docker image prune              # 只删悬空镜像
docker events                   # 实时查看 Docker 事件流（调试用）
```

## 9. 镜像构建与发布

```bash
docker build -t myapp:1.0 .      # 用当前目录的 Dockerfile 构建镜像
docker build -f Dockerfile.dev -t myapp:dev .  # 指定 Dockerfile
docker push myapp:1.0           # 推送到镜像仓库（需先 docker login）
docker login                    # 登录仓库
docker save -o myapp.tar myapp:1.0   # 导出镜像为 tar 文件
docker load -i myapp.tar        # 从 tar 文件导入镜像
```

## 10. 实验环境实例（MySQL 主从）

```bash
# 启动主库，映射 3307 端口，挂载配置和数据
docker run -d --name master \
  -p 3307:3307 \
  -v /data/mysql/master:/var/lib/mysql \
  -v /etc/my.cnf:/etc/mysql/conf.d/my.cnf \
  mysql:8.0

# 启动从库，加入同一个自定义网络，容器名 slave1
docker network create mysql-net
docker run -d --name slave1 --network mysql-net -p 3306:3306 mysql:8.0

# 进入容器执行 MySQL 客户端
docker exec -it master mysql -uroot -p

# 从容器内 ping 主库（自定义网络下用容器名）
docker exec slave1 ping master
```

## 常用排查流程

1. `docker ps -a` 看容器是否在运行、退出码是什么
2. `docker logs 容器名` 看启动报错
3. `docker inspect 容器名` 看端口、网络、挂载、环境变量是否配置正确
4. `docker exec -it 容器名 bash` 进容器里手动验证（如 `mysql -uroot -p` 能否连上）
5. 修改配置后必须 `docker restart 容器名`，很多 MySQL 参数（如 `server-id`、`log-bin`）不能热更新
