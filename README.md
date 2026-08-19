# PostgreSQL 表空间整理脚本

`postgres_table_compact.sh` 用于清理 PostgreSQL 表膨胀并显示处理前后的总占用空间。

## 使用方法

默认执行通常不阻塞正常读写的 `VACUUM (ANALYZE)`。它不会立即缩小磁盘文件，但释放的空间可以被后续写入重用：

```bash
./postgres_table_compact.sh \
  --database "postgresql://user@localhost/database" \
  --table public.orders
```

彻底重写表并将空间归还给操作系统：

```bash
./postgres_table_compact.sh \
  --database my_database \
  --table public.orders \
  --mode full
```

`full` 模式会独占锁表，并需要接近表大小的额外磁盘空间。自动化任务必须添加 `--yes`；可用 `--lock-timeout 10s` 限制锁等待时间。

生产环境的大表推荐安装 [`pg_repack`](https://reorg.github.io/pg_repack/) 后在线整理：

```bash
./postgres_table_compact.sh \
  --database my_database \
  --table public.orders \
  --mode repack
```

也可以使用 PostgreSQL 标准环境变量，避免把密码写入命令：

```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGDATABASE=my_database
export PGPASSWORD='your-password'

./postgres_table_compact.sh --table public.orders
```

查看完整参数：

```bash
./postgres_table_compact.sh --help
```

## 要求

- Bash 4+
- PostgreSQL 客户端 `psql`
- `repack` 模式额外要求 `pg_repack` 命令及数据库中的 `pg_repack` 扩展

建议先确认数据库有足够可用磁盘空间，并在执行 `full` 或 `repack` 前做好备份。