#!/usr/bin/env bash
# lint-runner.sh — llm-wiki 机械健康检查
# 用法：bash skill/scripts/lint-runner.sh <WIKI_ROOT>
# 输出：JSON 报告（stdout）；错误信息（stderr）；exit 0=成功，1=脚本错误

set -euo pipefail

WIKI_ROOT="${1:-}"
if [[ -z "$WIKI_ROOT" ]]; then
  echo "用法：bash lint-runner.sh <WIKI_ROOT>" >&2
  exit 1
fi

if [[ ! -d "$WIKI_ROOT/wiki" ]]; then
  echo "错误：$WIKI_ROOT/wiki 目录不存在" >&2
  exit 1
fi

WIKI_DIR="$WIKI_ROOT/wiki"
INDEX_FILE="$WIKI_ROOT/index.md"

# ─── 工具函数 ──────────────────────────────────────────────

# 提取文件中所有 [[wikilink]] 的目标（去掉 [[]] 和 # 锚点）
extract_wikilinks() {
  local file="$1"
  grep -oE '\[\[[^]]+\]\]' "$file" 2>/dev/null \
    | sed 's/\[\[//g; s/\]\]//g' \
    | sed 's/#.*//' \
    | sed 's/|.*//' \
    | sort -u
}

# 将 wikilink 路径转成实际文件路径
# 规则：[[concepts/foo]] → wiki/concepts/foo.md
#       [[foo]] → 在 wiki/ 下查找 foo.md
resolve_link() {
  local link="$1"
  # 如果包含 / 直接拼路径
  if [[ "$link" == *"/"* ]]; then
    echo "$WIKI_ROOT/${link}.md"
  else
    # 不含路径，在 wiki/ 子目录下搜索
    find "$WIKI_DIR" -name "${link}.md" -type f 2>/dev/null | head -1
  fi
}

# ─── 检查 1：孤立页（wiki/ 下不在 index.md 里的页面）─────────

orphan_pages=()
if [[ -f "$INDEX_FILE" ]]; then
  while IFS= read -r -d '' wiki_file; do
    rel_path="${wiki_file#$WIKI_ROOT/}"         # 相对路径，如 wiki/concepts/foo.md
    basename_no_ext="${wiki_file##*/}"
    basename_no_ext="${basename_no_ext%.md}"

    # 在 index.md 里搜索该文件（用路径或文件名均可）
    if ! grep -qF "$rel_path" "$INDEX_FILE" && \
       ! grep -qF "$basename_no_ext" "$INDEX_FILE"; then
      orphan_pages+=("$rel_path")
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0)
fi

# ─── 检查 2：断链（[[wikilink]] 指向不存在的文件）──────────────

broken_links=()
broken_links_seen=""   # 简单字符串去重（macOS bash3 兼容）

while IFS= read -r -d '' wiki_file; do
  rel_from="${wiki_file#$WIKI_ROOT/}"
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    target=$(resolve_link "$link")
    if [[ -z "$target" ]] || [[ ! -f "$target" ]]; then
      key="${rel_from}:::${link}"
      if [[ "$broken_links_seen" != *"|${key}|"* ]]; then
        broken_links_seen+="|${key}|"
        broken_links+=("{\"from\":\"$rel_from\",\"link\":\"[[$link]]\"}")
      fi
    fi
  done < <(extract_wikilinks "$wiki_file")
done < <(find "$WIKI_DIR" -name "*.md" -type f -print0)

# ─── 检查 3：index.md 中引用但 wiki/ 下不存在的页面 ────────────

missing_from_wiki=()
if [[ -f "$INDEX_FILE" ]]; then
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    target=$(resolve_link "$link")
    if [[ -z "$target" ]] || [[ ! -f "$target" ]]; then
      missing_from_wiki+=("$link")
    fi
  done < <(extract_wikilinks "$INDEX_FILE")
fi

# ─── 检查 4：缺少必填 frontmatter 字段 ─────────────────────────

missing_frontmatter=()
required_fields=("title" "type" "created" "status")

while IFS= read -r -d '' wiki_file; do
  rel_path="${wiki_file#$WIKI_ROOT/}"
  # 提取 frontmatter（--- 之间的内容）
  fm=$(awk '/^---/{count++; if(count==2) exit} count==1{print}' "$wiki_file" 2>/dev/null || true)
  if [[ -z "$fm" ]]; then
    missing_frontmatter+=("{\"path\":\"$rel_path\",\"missing\":[\"frontmatter缺失\"]}")
    continue
  fi
  missing_fields=()
  for field in "${required_fields[@]}"; do
    if ! echo "$fm" | grep -qE "^${field}:"; then
      missing_fields+=("$field")
    fi
  done
  if [[ ${#missing_fields[@]} -gt 0 ]]; then
    fields_json=$(printf '"%s",' "${missing_fields[@]}")
    fields_json="[${fields_json%,}]"
    missing_frontmatter+=("{\"path\":\"$rel_path\",\"missing\":${fields_json}}")
  fi
done < <(find "$WIKI_DIR" -name "*.md" -type f -print0)

# ─── 检查 5：source-signal 覆盖率（concepts/entities 无 sources 字段或为空）─────
# codeflicker-fix: P2-Issue-006/7qatih3meh7onycy27fd

no_source_signal=()
source_signal_dirs=("entities" "concepts")

for sub_dir in "${source_signal_dirs[@]}"; do
  target_dir="$WIKI_DIR/$sub_dir"
  [[ -d "$target_dir" ]] || continue
  while IFS= read -r -d '' wiki_file; do
    rel_path="${wiki_file#$WIKI_ROOT/}"
    fm=$(awk '/^---/{count++; if(count==2) exit} count==1{print}' "$wiki_file" 2>/dev/null || true)
    [[ -z "$fm" ]] && continue  # 无 frontmatter 已在检查 4 中记录

    # 检查 sources 字段是否存在且非空
    sources_line=$(echo "$fm" | grep -E "^sources:" || true)
    if [[ -z "$sources_line" ]]; then
      # sources 字段完全缺失
      no_source_signal+=("{\"path\":\"$rel_path\",\"reason\":\"sources字段缺失\"}")
    else
      # sources 字段存在，但检查是否为空数组 [] 或空值
      sources_val=$(echo "$sources_line" | sed 's/^sources://; s/^[[:space:]]*//')
      if [[ "$sources_val" == "[]" ]] || [[ -z "$sources_val" ]]; then
        no_source_signal+=("{\"path\":\"$rel_path\",\"reason\":\"sources为空，知识点无来源支撑\"}")
      fi
    fi
  done < <(find "$target_dir" -name "*.md" -type f -print0)
done

# ─── 输出 JSON 报告 ──────────────────────────────────────────────

# 辅助：数组转 JSON 数组字符串
array_to_json() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi
  local result="["
  for i in "${!arr[@]}"; do
    if [[ $i -gt 0 ]]; then result+=","; fi
    # 如果元素已经是 JSON 对象（以 { 开头），直接用；否则加引号
    if [[ "${arr[$i]}" == "{"* ]]; then
      result+="${arr[$i]}"
    else
      result+="\"${arr[$i]}\""
    fi
  done
  result+="]"
  echo "$result"
}

orphan_json=$(array_to_json "${orphan_pages[@]+"${orphan_pages[@]}"}")
broken_json=$(array_to_json "${broken_links[@]+"${broken_links[@]}"}")
missing_wiki_json=$(array_to_json "${missing_from_wiki[@]+"${missing_from_wiki[@]}"}")
fm_json=$(array_to_json "${missing_frontmatter[@]+"${missing_frontmatter[@]}"}")
no_source_json=$(array_to_json "${no_source_signal[@]+"${no_source_signal[@]}"}")

cat <<EOF
{
  "orphan_pages": ${orphan_json},
  "broken_links": ${broken_json},
  "missing_from_wiki": ${missing_wiki_json},
  "missing_frontmatter": ${fm_json},
  "no_source_signal": ${no_source_json},
  "summary": {
    "orphan_count": ${#orphan_pages[@]},
    "broken_link_count": ${#broken_links[@]},
    "missing_from_wiki_count": ${#missing_from_wiki[@]},
    "missing_frontmatter_count": ${#missing_frontmatter[@]},
    "no_source_signal_count": ${#no_source_signal[@]},
    "total_issues": $((${#orphan_pages[@]} + ${#broken_links[@]} + ${#missing_from_wiki[@]} + ${#missing_frontmatter[@]} + ${#no_source_signal[@]}))
  }
}
EOF
