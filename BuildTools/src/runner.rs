//! 子进程执行 + 按行流式收集输出。
//!
//! 用「UI 帧轮询」而不是「等待线程」：`Child::wait()` 需要 &mut Child，
//! 若在等待线程里长期持锁，界面上的「停止」就永远拿不到锁去 kill。

use std::io::Read;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{Receiver, Sender, TryRecvError, channel};
use std::sync::{Arc, Mutex};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Stream {
    Out,
    Err,
}

#[derive(Clone, Debug)]
pub struct Line {
    pub stream: Stream,
    pub text: String,
}

enum Event {
    Line(Line),
}

/// 一次子进程调用的完整描述
pub struct SpawnSpec {
    pub program: String,
    pub args: Vec<String>,
    pub cwd: Option<PathBuf>,
    pub envs: Vec<(String, String)>,
    /// 打印到输出面板的首行（命令行回显）
    pub banner: String,
}

pub struct Runner {
    child: Arc<Mutex<Child>>,
    rx: Receiver<Event>,
    killed: Arc<AtomicBool>,
    exit_code: Option<i32>,
    banner_sent: bool,
    banner: String,
}

#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

impl Runner {
    /// 启动子进程；`repaint` 用来在收到新输出时唤醒界面重绘。
    pub fn spawn<F>(spec: SpawnSpec, repaint: F) -> Result<Self, String>
    where
        F: Fn() + Send + Sync + 'static,
    {
        let mut cmd = Command::new(&spec.program);
        cmd.args(&spec.args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::null());
        if let Some(dir) = &spec.cwd {
            cmd.current_dir(dir);
        }
        for (k, v) in &spec.envs {
            cmd.env(k, v);
        }
        #[cfg(windows)]
        cmd.creation_flags(CREATE_NO_WINDOW);

        let mut child = cmd
            .spawn()
            .map_err(|e| format!("启动失败 {}: {e}", spec.program))?;

        let (tx, rx) = channel::<Event>();
        let repaint = Arc::new(repaint);

        for (pipe, stream) in [
            (
                child.stdout.take().map(|s| Box::new(s) as Box<dyn Read + Send>),
                Stream::Out,
            ),
            (
                child.stderr.take().map(|s| Box::new(s) as Box<dyn Read + Send>),
                Stream::Err,
            ),
        ] {
            let Some(pipe) = pipe else { continue };
            let tx = tx.clone();
            let repaint = Arc::clone(&repaint);
            std::thread::spawn(move || {
                pump(pipe, stream, &tx, repaint.as_ref());
                repaint();
            });
        }
        // 原始 tx 到这里析构；两个读取线程退出后 channel 变为 Disconnected，
        // 界面上就是靠这个信号判定"输出已读完"。
        drop(tx);

        Ok(Runner {
            child: Arc::new(Mutex::new(child)),
            rx,
            killed: Arc::new(AtomicBool::new(false)),
            exit_code: None,
            banner_sent: false,
            banner: spec.banner,
        })
    }

    pub fn is_running(&self) -> bool {
        self.exit_code.is_none()
    }

    pub fn kill(&self) -> Result<(), String> {
        self.killed.store(true, Ordering::SeqCst);
        let mut child = self.child.lock().map_err(|_| "进程句柄已失效".to_string())?;
        child.kill().map_err(|e| format!("停止失败: {e}"))
    }

    /// 取本次新增的输出行；进程结束且输出读完后 `exit_code` 变为 Some。
    ///
    /// 结束判定用 channel 的 `Disconnected`（两个读取线程都退出、且缓冲已排空）
    /// 而不是「读取线程计数归零」—— 后者存在"行已发出但计数已减到 0"的竞态，
    /// 会让最后几行输出丢掉。
    pub fn poll(&mut self) -> Vec<Line> {
        let mut out = Vec::new();

        if !self.banner_sent {
            self.banner_sent = true;
            out.push(Line {
                stream: Stream::Out,
                text: format!("> {}", self.banner),
            });
        }

        let mut closed = false;
        loop {
            match self.rx.try_recv() {
                Ok(Event::Line(l)) => out.push(l),
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => {
                    closed = true;
                    break;
                }
            }
        }

        if closed && self.exit_code.is_none() {
            let Ok(mut child) = self.child.lock() else {
                return out;
            };
            match child.try_wait() {
                Ok(Some(status)) => {
                    let code = status.code().unwrap_or(-1);
                    self.exit_code = Some(code);
                    let killed = self.killed.load(Ordering::SeqCst);
                    out.push(Line {
                        stream: if code == 0 { Stream::Out } else { Stream::Err },
                        text: if killed {
                            format!("[已停止] 退出码 {code}")
                        } else {
                            format!("[进程结束] 退出码 {code}")
                        },
                    });
                }
                Ok(None) => {}
                Err(e) => {
                    self.exit_code = Some(-1);
                    out.push(Line {
                        stream: Stream::Err,
                        text: format!("[等待进程失败] {e}"),
                    });
                }
            }
        }

        out
    }
}

/// 逐块读取并切行：以 \n 与 \r 都作为分隔（兼容进度式回车刷新），
/// 残余留在 pending 里等下一块，避免把多字节字符切成两半。
fn pump<F>(mut reader: Box<dyn Read + Send>, stream: Stream, tx: &Sender<Event>, repaint: &F)
where
    F: Fn(),
{
    let mut chunk = [0u8; 8192];
    let mut pending: Vec<u8> = Vec::new();

    loop {
        let n = match reader.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => n,
            Err(_) => break,
        };
        pending.extend_from_slice(&chunk[..n]);

        let mut start = 0usize;
        for i in 0..pending.len() {
            if pending[i] == b'\n' || pending[i] == b'\r' {
                if i > start {
                    let _ = tx.send(Event::Line(Line {
                        stream,
                        text: decode(&pending[start..i]),
                    }));
                }
                start = i + 1;
            }
        }
        if start > 0 {
            pending.drain(..start);
        }
        repaint();
    }

    if !pending.is_empty() {
        let _ = tx.send(Event::Line(Line {
            stream,
            text: decode(&pending),
        }));
    }
}

/// 优先按 UTF-8 解码；失败（例如 Python 在管道下按 GBK 输出）再退回 GBK。
fn decode(bytes: &[u8]) -> String {
    match std::str::from_utf8(bytes) {
        Ok(s) => s.to_string(),
        Err(_) => encoding_rs::GBK.decode(bytes).0.into_owned(),
    }
}
