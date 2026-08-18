# CentOS 7 虚拟机固定 IP 配置记录

本文记录将 VMware 虚拟机（CentOS 7.4，主机名 `xuniji`）的网卡 `ens32` 从 DHCP 动态分配改为静态 IP 的完整过程。

## 环境说明

- 虚拟机软件：VMware，网络模式 NAT
- 系统：CentOS Linux release 7.4.1708
- 网卡：`ens32`，MAC `00:0c:29:...`（VMware 虚拟机网卡特征）
- 固定 IP：`192.168.157.147/24`
- 网关：`192.168.157.2`（VMware NAT 模式网关一般是 `192.168.x.2`）
- DNS：`192.168.157.2`

原始状态：`ens32` 为 DHCP 动态分配，`ip addr` 中显示 `scope global dynamic`，租约只有约 25 分钟，IP 会漂移，因此需要固定。

## 1. 查看当前网络状态

```bash
ip addr
ip route
cat /etc/resolv.conf
```

关键信息：

- `ip addr`：确认网卡名（这里是 `ens32`）以及当前是否动态分配（`dynamic` 字样）
- `ip route`：`default via 192.168.157.2 dev ens32` 这一行就是网关
- `/etc/resolv.conf`：当前 DNS

## 2. 找到 NetworkManager 的连接名

CentOS 7 默认由 NetworkManager 管理网络，`/etc/sysconfig/network-scripts/ifcfg-ens32` 不一定存在，所以不能直接改 ifcfg 文件，要先查连接名：

```bash
nmcli con show
```

示例输出：

```text
NAME                UUID                                  TYPE            DEVICE
Wired connection 3  11ac45c9-...                          802-3-ethernet  ens32
```

注意：连接名不一定是网卡名，这里叫 `Wired connection 3`。连接名带空格，命令中必须加引号；直接 `nmcli con mod ens32 ...` 会报 `Error: unknown connection 'ens32'`。

## 3. 配置静态 IP

```bash
nmcli con mod "Wired connection 3" ipv4.addresses 192.168.157.147/24
nmcli con mod "Wired connection 3" ipv4.gateway 192.168.157.2
nmcli con mod "Wired connection 3" ipv4.dns 192.168.157.2
nmcli con mod "Wired connection 3" ipv4.method manual
nmcli con up "Wired connection 3"
```

也可以自动取当前活动连接名，避免手写：

```bash
NAME=$(nmcli -t -f NAME,DEVICE con show | grep ens32 | cut -d: -f1)
nmcli con mod "$NAME" ipv4.addresses 192.168.157.147/24 ipv4.gateway 192.168.157.2 ipv4.dns 192.168.157.2 ipv4.method manual
nmcli con up "$NAME"
```

如果 `nmcli con show` 里没有 ens32 对应的连接，先手动创建再配置：

```bash
nmcli con add type ethernet con-name ens32 ifname ens32
```

## 4. 验证

```bash
ip addr show ens32
ping -c 3 192.168.157.2
ping -c 3 www.baidu.com
```

成功标志：

- `ip addr` 显示 `inet 192.168.157.147/24 ... scope global ens32`，`valid_lft forever`，没有 `dynamic` 字样
- 网关 ping 通（NAT 模式）
- 外网 ping 通（`www.baidu.com` 解析到公网 IP）
- 建议 `reboot` 后再确认一次，重启后 IP 不变才算固定成功

## 5. 其他系统的写法（备用）

CentOS 7 老式配置文件方式（NetworkManager 未接管时）：

```ini
# /etc/sysconfig/network-scripts/ifcfg-ens32
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.157.147
NETMASK=255.255.255.0
GATEWAY=192.168.157.2
DNS1=192.168.157.2
```

```bash
systemctl restart network
```

CentOS 8+ / Rocky / Alma：使用同样的 `nmcli` 命令即可。

Ubuntu 18.04+（netplan）：

```yaml
# /etc/netplan/00-installer-config.yaml
network:
  ethernets:
    ens32:
      dhcp4: false
      addresses: [192.168.157.147/24]
      routes:
        - to: default
          via: 192.168.157.2
      nameservers:
        addresses: [192.168.157.2, 223.5.5.5]
  version: 2
```

```bash
sudo netplan apply
```

## 6. 常见坑

- VMware NAT 模式网关是 `192.168.x.2`；桥接模式要和宿主机同一网段，且 IP 不能冲突；仅主机模式只能和宿主机互通
- NetworkManager 管理的连接名带空格，`nmcli` 命令里必须加引号
- 固定成当前 DHCP 分配的 IP，可以避免和 DHCP 地址池冲突
- `nmcli con show` 里未绑定设备的旧连接（如 `Wired connection 1`、`ens160`）可清理：

```bash
nmcli con delete "Wired connection 1" "Wired connection 2"
```
