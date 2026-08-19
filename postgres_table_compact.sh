#!/usr/bin/env bash

set -Eeuo pipefail

PROGRAM_NAME="$(basename "$0")"
DATABASE="${PGDATABASE:-}"
TABLE_NAME=""
MODE="vacuum"
LOCK_TIMEOUT="5s"
ASSUME_YES=false

usage() {
  cat <<EOF
用法:
  $PROGRAM_NAME --table <schema.table> [选项]

选项:
  -d, --database <连接串>   数据库名或 PostgreSQL 连接串（默认使用 PGDATABASE）
  -t, --table <表名>       要处理的表，例如 public.orders
  -m, --mode <模式>        vacuum（默认）、full 或 repack
      --lock-timeout <值>  full 模式等待表锁的时间（默认 5s）
  -y, --yes                跳过 full 模式的确认
  -h, --help               显示帮助

模式:
  vacuum  执行 VACUUM (ANALYZE)，空间供 PostgreSQL 重用，通常不阻塞读写
  full    执行 VACUUM (FULL, ANALYZE)，归还磁盘空间，但会锁表
  repack  使用 pg_repack 在线重建表，通常仅短暂锁表

连接也可以通过 PGHOST、PGPORT、PGUSER、PGPASSWORD 和 PGDATABASE 设置。
EOF
}

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

while (($# > 0)); do
  case "$1" in
    -d|--database)
      (($# >= 2)) || die "$1 缺少参数"
      DATABASE="$2"
      shift 2
      ;;
    -t|--table)
      (($# >= 2)) || die "$1 缺少参数"
      TABLE_NAME="$2"
      shift 2
      ;;
    -m|--mode)
      (($# >= 2)) || die "$1 缺少参数"
      MODE="$2"
      shift 2
      ;;
    --lock-timeout)
      (($# >= 2)) || die "$1 缺少参数"
      LOCK_TIMEOUT="$2"
      shift 2
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数: $1（使用 --help 查看帮助）"
      ;;
  esac
done

[[ -n "$TABLE_NAME" ]] || die "必须通过 --table 指定表"
[[ "$MODE" =~ ^(vacuum|full|repack)$ ]] || die "--mode 只能是 vacuum、full 或 repack"
command_exists psql || die "未找到 psql，请先安装 PostgreSQL 客户端"

PSQL=(psql -X --set ON_ERROR_STOP=1 --no-psqlrc)
if [[ -n "$DATABASE" ]]; then
  PSQL+=(--dbname "$DATABASE")
fi

# 由 PostgreSQL 解析输入并生成带引号的限定名，避免名称注入和大小写问题。
QUALIFIED_TABLE="$(
  "${PSQL[@]}" --quiet --tuples-only --no-align \
    --set "input_table=$TABLE_NAME" \
    --command "SELECT format('%I.%I', n.nspname, c.relname)
               FROM pg_catalog.pg_class AS c
               JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
               WHERE c.oid = to_regclass(:'input_table')
                 AND c.relkind IN ('r', 'p', 'm');"
)"
[[ -n "$QUALIFIED_TABLE" ]] || die "表不存在或不是普通表、分区表、物化视图: $TABLE_NAME"

show_size() {
  local label="$1"
  "${PSQL[@]}" --quiet --tuples-only --no-align \
    --set "input_table=$QUALIFIED_TABLE" \
    --command "SELECT '$label: ' || pg_size_pretty(pg_total_relation_size(to_regclass(:'input_table')));"
}

printf '目标表: %s\n模式: %s\n' "$QUALIFIED_TABLE" "$MODE"
show_size "处理前"

case "$MODE" in
  vacuum)
    "${PSQL[@]}" --command "VACUUM (ANALYZE) $QUALIFIED_TABLE;"
    ;;
  full)
    if [[ "$ASSUME_YES" != true ]]; then
      if [[ ! -t 0 ]]; then
        die "full 模式会锁表；非交互运行时请明确添加 --yes"
      fi
      printf 'VACUUM FULL 会锁定 %s，并需要额外磁盘空间。继续？[y/N] ' "$QUALIFIED_TABLE"
      read -r answer
      [[ "$answer" =~ ^[Yy]$ ]] || die "已取消"
    fi
    PGOPTIONS="${PGOPTIONS:+$PGOPTIONS }-c lock_timeout=$LOCK_TIMEOUT" \
      "${PSQL[@]}" --command "VACUUM (FULL, ANALYZE) $QUALIFIED_TABLE;"
    ;;
  repack)
    command_exists pg_repack || die "未找到 pg_repack，请先安装并在数据库中启用该扩展"
    REPACK=(pg_repack --table "$QUALIFIED_TABLE")
    if [[ -n "$DATABASE" ]]; then
      REPACK+=(--dbname "$DATABASE")
    fi
    "${REPACK[@]}"
    "${PSQL[@]}" --command "ANALYZE $QUALIFIED_TABLE;"
    ;;
esac

show_size "处理后"
printf '处理完成。\n'
