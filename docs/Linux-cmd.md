
---

### 速查

| 命令 | 用途 |
|------|------|
| `sed` | 替换、删行、插行 |
| `awk` | 按列计算、过滤 |
| `grep` | 搜索匹配行 |
| `cut` | 简单按分隔符取列 |
| `sort`/`uniq` | 排序、去重 |
| `tr` | 字符替换/删除 |
| `paste` | 多文件按列合并 |

---

#### 某个目录下查文件内容是否包含 7000
```bash
grep -rn "7000" /path/to/dir
```
---

#### dmesg 命令
```bash
# 查看内核日志
dmesg
# 最后 30 行（你之前排查 USB 用过）
dmesg | tail -30
# 实时跟踪（插拔设备时看）
dmesg -w
# 带时间戳（易读）
dmesg -T
# 只看错误/警告
dmesg --level=err,warn
# 清除环缓（需 root）
sudo dmesg -C
```

---

### sed（流编辑，改文本）

```bash
# 替换（只显示，不改文件）
sed 's/旧/新/' file
sed 's/旧/新/g' file          # 每行全部替换

# 直接改文件（-i）
sed -i 's/旧/新/g' file
sed -i 's/旧/新/g' *.txt      # 批量

# 删除含某关键字的行
sed -i '/关键字/d' file

# 打印第 5 行
sed -n '5p' file

# 打印 5~10 行
sed -n '5,10p' file

# 在某行后插入
sed -i '3a\新的一行' file
```

---

### awk（按列处理）

```bash
# 默认按空格/制表符分列
awk '{print $1}' file         # 第 1 列
awk '{print $1, $3}' file     # 第 1、3 列
awk -F: '{print $1}' /etc/passwd   # 以 : 分隔

# 带条件
awk '$3 > 100' file           # 第 3 列 > 100
awk '/error/ {print $0}' file # 含 error 的行

# 统计
awk '{sum+=$1} END {print sum}' file
awk 'END {print NR}' file     # 行数
```

---

### 和 grep / cut 一起用

```bash
grep "error" app.log
grep -n "error" app.log       # 带行号
grep -rn "7000" .             # 目录递归搜
grep -v "debug" file          # 排除

cut -d: -f1 /etc/passwd       # 按 : 取第 1 段
cut -c1-10 file               # 取每行前 10 个字符
```

---

### sort / uniq / wc

```bash
sort file
sort -n file                  # 按数字
sort -k2 file                 # 按第 2 列

uniq file                     # 去重（需先 sort）
sort file | uniq
sort file | uniq -c           # 计数

wc -l file                    # 行数
wc -c file                    # 字节数
```

---

### 常见组合例子

```bash
# 日志里统计 IP 出现次数
awk '{print $1}' access.log | sort | uniq -c | sort -nr

# 配置文件改端口
sed -i 's/8080/9000/g' config.ini

# 取 CSV 第 2 列
awk -F, '{print $2}' data.csv

# 去掉空行
sed '/^$/d' file
```
