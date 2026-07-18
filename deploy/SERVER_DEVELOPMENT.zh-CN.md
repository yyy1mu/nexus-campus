# Nexus 服务器开发与运维

## 当前环境

- 系统：Ubuntu 24.04 LTS
- 部署目录：`/opt/nexus-campus`
- 前端：Nginx，监听服务器 `80`
- 后端：Spring Boot，由 `nexus-campus.service` 管理，仅监听本机 `8080`
- 数据：MySQL `3306`、Redis `6379`，均仅监听本机
- 密钥配置：`/etc/nexus-campus/nexus-campus.env`，权限 `0600`
- Maven 与 npm 已配置 USTC 代理，避免境外依赖源超时

不要把 SSH、数据库或 GitLab token 写入仓库。不要将环境文件加入 Git。

## 网络说明

服务器网卡地址是 `192.167.33.3`。当前外部地址只配置了：

```text
114.214.241.48:8611 -> 192.167.33.3:22
```

因此 SSH 可用，但外部浏览器目前不能直接访问 Nginx。需要服务器/NAT 管理员新增：

```text
114.214.241.48:<HTTP端口> -> 192.167.33.3:80
```

正式公开前再配置域名、`443` 映射和 TLS 证书。端口映射完成后，所有 Agent 文档和 API 都使用同一个站点 origin。

## 更新部署

在代码更新并完成检查后执行：

```bash
cd /opt/nexus-campus
sudo bash deploy/native/install-or-update.sh
```

脚本会保留已有数据库密码，重新构建后端和前端，并重启后端。首次 Maven 下载较慢，后续使用本地缓存通常只需数秒。

## 日常命令

```bash
systemctl status nexus-campus nginx mysql redis-server
journalctl -u nexus-campus -f
systemctl restart nexus-campus
nginx -t && systemctl reload nginx
curl http://127.0.0.1/api/nexus/agent-health
```

数据库备份示例：

```bash
install -d -m 0700 /var/backups/nexus-campus
mysqldump --protocol=socket -uroot --single-transaction nexus_campus \
  | gzip > /var/backups/nexus-campus/nexus-$(date +%F-%H%M%S).sql.gz
```

## Agent 验收

公开入口应全部返回 `200`：

- `/api/nexus/agent-health`
- `/llms.txt`
- `/.well-known/nexus-agent.json`
- `/docs/agent-quickstart.md`
- `/docs/agent-tools.json`
- `/v3/api-docs`
- `/swagger-ui.html`

发布后至少验证一次双用户链路：

1. 注册或登录两个用户。
2. 打开 Agent matching 权限并登记 helper capability。
3. 创建 help request。
4. 测试 dispatch 创建和接受。
5. 测试 match offer 和接受。
6. 接受后发送私聊消息，并由另一参与方读取。
7. 创建、读取并召回一条私有长期记忆。
8. 在 accepted match 中共享记忆快照，验证双方可读、第三方 `403`，然后由所有者撤销。

非 match 参与者必须不能读取消息、共享记忆或变更 match 状态；未接受的 match 必须不能发送消息或创建记忆共享。

## 已知限制

- 后端当前有 9 项自动化测试，覆盖 Agent memory service/controller/repository 及 match 非参与者授权。部署前必须确认 `mvn test` 的失败数和错误数均为 0。
- Docker 与 Compose 已安装，但服务器当前无法访问 Docker Hub；现阶段使用原生 systemd 部署。
- `SPRING_JPA_HIBERNATE_DDL_AUTO=update` 适合当前开发阶段，进入正式生产前应改成受版本控制的 Flyway migration。
