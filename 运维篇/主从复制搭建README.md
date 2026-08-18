# MySQL 8 主从复制搭建记录

本文档记录本次 MySQL 主从复制实验的环境、配置步骤、验证方法以及排错过程。

## 环境说明

- 宿主机：`xuniji`，Docker 默认网桥 `docker0` 地址为 `172.17.0.1`
- 主库：MySQL 8.0.39，监听在宿主机 `*:3307`，binlog 文件前缀为 `binlog`
- 从库：`slave1` Docker 容器，MySQL 8.0.46，容器 IP `192.168.10.12`，本地端口 `3306`
- 从库通过 `172.17.0.1:3307` 连接主库
- 宿主机物理 IP `192.169.157.152` 可 ping 通，但 `3307` 被宿主机防火墙拦截，因此实验中改用 `172.17.0.1` 作为复制源地址

## 1. 主库配置

编辑 `/etc/my.cnf`，在 `[mysqld]` 下添加：

```ini
[mysqld]
port = 3307
server-id = 1
log-bin = binlog
binlog-format = ROW
bind-address = 0.0.0.0
```

重启 MySQL 后确认 binlog 已开启：

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW MASTER STATUS;
```

创建复制账号（推荐使用专用账号）：

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'Repl@123456';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
```

本次实验直接使用 `root`，需要确保 `root@'%'` 存在且密码正确：

```sql
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
FLUSH PRIVILEGES;
```

## 2. 从库配置

编辑 `/etc/my.cnf`，在 `[mysqld]` 下添加：

```ini
[mysqld]
server-id = 2
relay-log = slave1-relay-bin
read_only = 1
```

重启从库 MySQL。

## 3. 配置复制

在主库查询当前 binlog 位置：

```sql
SHOW MASTER STATUS;
```

示例输出：

```text
+---------------+----------+------------------+-------------------+
| File          | Position | Binlog_Do_DB     | Binlog_Ignore_DB  |
+---------------+----------+------------------+-------------------+
| binlog.000007 |     2017 |                  |                   |
+---------------+----------+------------------+-------------------+
```

在从库执行：

```sql
STOP REPLICA;

CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='172.17.0.1',
  SOURCE_PORT=3307,
  SOURCE_USER='root',
  SOURCE_PASSWORD='123456',
  SOURCE_LOG_FILE='binlog.000007',
  SOURCE_LOG_POS=2017;

START REPLICA;
```

注意：`SOURCE_LOG_FILE` 必须与 `SHOW MASTER STATUS` 返回的 `File` 完全一致，不要自行补 `mysql-` 前缀。

检查复制状态：

```sql
SHOW REPLICA STATUS\G
```

成功标志：

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
Replica_IO_State: Waiting for source to send event
```

## 4. 验证复制

在主库执行：

```sql
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;
CREATE TABLE IF NOT EXISTS t1 (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO t1 VALUES (1, 'hello');
UPDATE t1 SET name = 'world' WHERE id = 1;
```

在从库查询：

```sql
SELECT * FROM test_db.t1;
```

如果能看到主库写入的数据，说明主从复制正常。

## 5. 同步主库已有数据

复制只同步启动位置之后的新变更。主库已有的 `itcast`、`web` 等库需要手动导出导入。

在从库容器执行：

```bash
mysqldump -h172.17.0.1 -P3307 -uroot -p \
  --databases itcast web \
  --single-transaction --routines --triggers \
  > /tmp/sync.sql
```

如果 dump 中包含 `DEFINER='root'@'%'` 的视图、存储过程或触发器，先在从库创建同名账号：

```sql
CREATE USER 'root'@'%' IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

导入从库：

```bash
mysql -uroot -p < /tmp/sync.sql
```

导入完成后继续复制：

```sql
START REPLICA;
SHOW REPLICA STATUS\G
```

需要从一致快照重新搭建时，可以执行完整流程：

```sql
STOP REPLICA;
RESET REPLICA ALL;
```

```bash
mysqldump -h172.17.0.1 -P3307 -uroot -p \
  --databases itcast web \
  --single-transaction --source-data=2 --routines --triggers \
  > /tmp/full.sql

mysql -uroot -p < /tmp/full.sql
```

从导出文件查找 binlog 位置：

```bash
grep -n "CHANGE" /tmp/full.sql
```

使用该位置重新配置并启动复制：

```sql
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='172.17.0.1',
  SOURCE_PORT=3307,
  SOURCE_USER='root',
  SOURCE_PASSWORD='123456',
  SOURCE_LOG_FILE='<grep 得到的 File>',
  SOURCE_LOG_POS=<grep 得到的 Position>;

START REPLICA;
```

## 6. 排错记录

### 2003 / 111 / 110：连接不上主库

- `111`：端口拒绝，先检查主库是否监听：`ss -tlnp | grep 3307`
- `110`：连接超时，通常是防火墙丢包
- 从容器连接宿主机 MySQL 时，优先测试 `172.17.0.1:3307`
- 宿主机物理 IP 被防火墙拦截时放行端口：

```bash
firewall-cmd --permanent --add-port=3307/tcp
firewall-cmd --reload
```

### 1045：Access denied

账号、密码或认证插件不匹配。检查：

```sql
SELECT user, host, plugin, password_expired, account_locked
FROM mysql.user WHERE user='root';
```

在主库修正：

```sql
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '123456';
FLUSH PRIVILEGES;
```

### 1236：找不到 binlog 文件

`SOURCE_LOG_FILE` 文件名写错，比如把 `binlog.000007` 写成 `mysql-bin.000007`。必须使用 `SHOW MASTER STATUS` 返回的准确 `File`。

### 1049：Unknown database

主库 binlog 中引用的数据库在从库不存在。把对应数据库从主库 dump 后导入从库，再 `START REPLICA`。

### 1449：DEFINER 用户不存在

dump 中的视图、存储过程或触发器使用 `root@'%'`，从库没有该账号。在从库先创建 `root@'%'`，再重新导入。

### DataGrip 断开

修改了 MySQL 密码后，DataGrip 仍保存旧密码，需要在连接属性中更新密码并重新测试连接。
