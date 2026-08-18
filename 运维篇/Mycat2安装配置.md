# Mycat2 安装配置记录（CentOS 7）

本文记录在 CentOS 7.4 虚拟机上安装并启动 Mycat2（1.21 发行包 + 1.20 安装模板）的完整过程，包括下载、配置、启动验证和常见坑。

## 环境说明

- 系统：CentOS Linux release 7.4.1708，JDK 1.8.0_412
- Mycat2：`mycat2-1.21-release-jar-with-dependencies.jar`（运行包，135MB）
- 安装模板：`mycat2-install-template-1.20.zip`（外壳，含 bin/conf/lib 骨架）
- 安装目录：`/usr/local/mycat`
- 后端 MySQL：本机 `localhost:3307`，账号 `root`，密码 `123456`
- Mycat 业务端口：8066；管理端口：9066

## 1. 下载安装包

Mycat2 的安装包由两部分组成：安装模板（shell 骨架）+ fat jar（运行包）。

注意：

- 官方下载站 `dl.mycat.org.cn` 已停服（域名无法解析），`dl.mycat.io` 也只剩 HTML 错误页
- GitHub 官方 release（`MyCATApache/Mycat2`）只有源码包，没有发行包，解压后没有 bin/conf/lib
- 可用第三方镜像站：`download.topunix.com`，目录 `https://download.topunix.com/MySQL/Software-Cluster/Software-Mycat/Mycat2/`

下载命令（证书可能有问题，加 `--no-check-certificate`）：

```bash
cd /usr/local
wget --no-check-certificate https://download.topunix.com/MySQL/Software-Cluster/Software-Mycat/Mycat2/mycat2-install-template-1.20.zip
wget --no-check-certificate https://download.topunix.com/MySQL/Software-Cluster/Software-Mycat/Mycat2/mycat2-1.21-release-jar-with-dependencies.jar
```

## 2. 解压安装

模板是 zip 包，用 `unzip` 而不是 `tar`：

```bash
yum install -y unzip
cd /usr/local
unzip mycat2-install-template-1.20.zip
mv mycat2-1.21-release-jar-with-dependencies.jar mycat/lib/
ls mycat/
```

解压后必须看到 `bin conf lib` 三个目录。

## 3. 安装 JDK 8

Mycat2 依赖 JDK 8：

```bash
yum install -y java-1.8.0-openjdk-devel
java -version
```

## 4. 启动权限

解压后 bin 下的脚本可能没有执行权限，直接 `mycat start` 会报 `Permission denied`：

```bash
chmod +x /usr/local/mycat/bin/*
```

## 5. 配置数据源

Mycat2 的配置在 `conf/` 下，分层模型：

- `datasources/*.json`：物理数据源（连哪台真实 MySQL）
- `clusters/*.json`：集群（一组数据源）
- `schemas/*.json`：逻辑库（映射到集群）
- `users/*.json`：连接 Mycat 的客户端账号

默认数据源 `prototypeDs` 指向 `localhost:3306`，需要改成真实 MySQL 地址：

```bash
cat /usr/local/mycat/conf/datasources/*.json
```

```json
{
  "dbType": "mysql",
  "name": "prototypeDs",
  "url": "jdbc:mysql://localhost:3307/mysql?useUnicode=true&serverTimezone=Asia/Shanghai&characterEncoding=UTF-8",
  "user": "root",
  "password": "123456"
}
```

客户端账号默认 `root/123456`（`users/*.json`），逻辑库默认 `mysql` 映射到 `prototype` 集群（`schemas/*.json`）。

## 6. 启动与验证

```bash
/usr/local/mycat/bin/mycat start
/usr/local/mycat/bin/mycat status
ss -tlnp | grep -E '8066|9066'
```

测试连接：

```bash
mysql -h127.0.0.1 -P8066 -uroot -p123456
SHOW DATABASES;
```

成功标志：连接后 Server version 显示类似 `5.7.33-mycat-2.0`，能看到逻辑库。

## 7. 常见坑

### 启动后立即崩溃

症状：`mycat status` 显示 running，但过一会儿 java 进程消失，`ss` 看不到 8066。

日志位置：`logs/wrapper.log`（不是 `logs/mycat.log`）。

典型错误：

```text
GetConnectionTimeoutException: wait millis 3000 ... 
Caused by: java.net.ConnectException: Connection refused
```

原因：Mycat 启动时要连后端 MySQL 读取系统变量，数据源连不上（地址/端口/账号不对，或 MySQL 没启动）就直接退出。检查：

```bash
ss -tlnp | grep 3307
mysql -h127.0.0.1 -P3307 -uroot -p123456 -e "select version();"
```

### 源码包误当发行包

GitHub 自动生成的 `Mycat2-1.22-2022-6-25.tar.gz` 是源码（有 pom.xml），没有 bin/conf/lib，不能直接启动。

### 管理端口只监听本机

9066 只绑在 `127.0.0.1` 是正常现象；业务端口 8066 绑定 `0.0.0.0`（`conf/server.json` 中的 `ip` 配置）。
