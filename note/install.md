这是一个非常典型的 APT 包管理器依赖死锁（Dependency Hell）错误。

在你尝试降级或安装软件时，系统现有的组件 `libtsan0`（ThreadSanitizer 线程分析库）死死地锁定了旧版本的 `gcc-10-base (= 10-20200411-ok5)`。而你当前为了满足其他软件（或 GCC 9），系统正准备强制安装 `10.5.0-ok3`，导致新旧版本冲突，APT 只能选择拒绝执行。

既然你的终极目标是**降级到 GCC 9**，那么当前的 `gcc-10-base` 相关的周边调试库（如 `libtsan0`）完全是可以暂时牺牲掉的。请按照以下工业级清理流水线，强行破除依赖死锁：

---

### 🛠️ 核心解决方案：强行卸载冲突源并清理环境

#### 第一步：卸载导致死锁的 `libtsan0`

既然是它在挡路，我们直接把它和它的基础库一起卸载掉。放心，这只是个编译器配套的线程检测工具，卸载它绝对不会损坏你的系统桌面。

```bash
sudo apt-get remove --purge libtsan0 gcc-10-base

```

#### 第二步：强制修复可能损坏的依赖链

卸载完冲突源后，让 APT 重新梳理并清空之前卡住的安装队列：

```bash
sudo apt-get clean
sudo apt-get update
sudo apt-get install -f

```

---

### 🚀 第三步：重新安全安装 `gcc-9` 和 `g++-9`

现在依赖树已经被荡平，你可以顺畅地执行降级安装了。

```bash
# 1. 重新安装 GCC 9
sudo apt-get install -y gcc-9 g++-9

# 2. 如果之前执行过 update-alternatives，重新注册并切换一次：
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 90

# 3. 强制选到 9 
sudo update-alternatives --config gcc
sudo update-alternatives --config g++

```

---

### 💡 备用大招：如果系统依然死锁（利用 `aptitude` 智能调解）

如果执行第一步时，系统又提示其他一百个包依赖 `gcc-10-base` 导致无法卸载，千万不要去盲目一个个删。改用高级包管理器 **`aptitude`**，它拥有比 `apt-get` 聪明十倍的依赖解决算法，会为你计算出多个折中方案。

1. **安装 `aptitude**`：
```bash
sudo apt-get install aptitude -y

```


2. **用 `aptitude` 来安装 `gcc-9**`：
```bash
sudo aptitude install gcc-9 g++-9

```


3. **关键操作**：
运行后，`aptitude` 会给出一个方案。
* **第一个方案通常是“保持现状（不安装gcc-9）”**，这时它会问你 `[Y/n/q/?]`，**请果断键盘输入 `n`（代表 No，拒绝这个不安装的方案）**。
* 随后它会计算出**第二个方案**（通常是自动帮你升级、降级或替换掉冲突的 `libtsan0`、`gcc-10-base`），看到真正进行降级/替换的方案时，**键盘输入 `y`（代表 Yes，执行）**。



环境洗干净后，再回去编译你的 G6 SDK 项目，阻碍就彻底扫清了！