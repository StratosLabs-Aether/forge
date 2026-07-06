//! Aether Forge IDE — Tauri 2.0 main process
//!
//! This is the Rust backend for the Aether Forge IDE. It handles:
//!   - File system operations (read/write/list)
//!   - Aether LSP process management (spawns aether-lsp on demand)
//!   - Scrible AI agent (Ollama HTTP bridge for completions and chat)
//!   - Aether runtime execution (spawns aether CLI)
//!
//! Architecture:
//!   ┌────────────────────────────────────────────────────┐
//!   │  WebView (CodeMirror 6 + HTML/CSS/JS)              │
//!   │  ↔ Tauri IPC (JSON commands)                       │
//!   ├────────────────────────────────────────────────────┤
//!   │  Rust Backend (this file)                          │
//!   │  ├── File ops                                     │
//!   │  ├── aether-lsp manager                           │
//!   │  ├── Scrible AI (Ollama HTTP)                     │
//!   │  └── aether runtime (CLI spawn)                   │
//!   └────────────────────────────────────────────────────┘

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::sync::Arc;
use tauri::State;

// ═══════════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════════

struct TerminalState {
    output: Vec<u8>,
    stdin: Option<std::process::ChildStdin>,
    child: Option<Child>,
    done: bool,
    exit_code: Option<i32>,
}

struct ForgeState {
    aether_process: Mutex<Option<Child>>,
    lsp_process: Mutex<Option<Child>>,
    terminal: Arc<Mutex<TerminalState>>,
}

// ═══════════════════════════════════════════════════════════════════
// IPC Commands
// ═══════════════════════════════════════════════════════════════════

#[derive(Debug, Serialize, Deserialize)]
struct FileEntry {
    name: String,
    is_directory: bool,
    path: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct FileResult {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    content: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    entries: Option<Vec<FileEntry>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ScribleQuery {
    endpoint: String,
    model: String,
    prompt: String,
    #[serde(default)]
    temperature: f64,
    #[serde(default = "default_max_tokens")]
    max_tokens: u32,
}

fn default_max_tokens() -> u32 {
    256
}

#[derive(Debug, Serialize)]
struct ScribleResult {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    response: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ScribleChatQuery {
    endpoint: String,
    model: String,
    messages: Vec<ChatMessage>,
    #[serde(default)]
    temperature: f64,
    #[serde(default = "default_max_tokens")]
    max_tokens: u32,
}

#[derive(Debug, Serialize, Deserialize)]
struct ChatMessage {
    role: String,
    content: String,
}

// ── File Operations ────────────────────────────────────────────────

#[tauri::command]
fn read_file(path: String) -> FileResult {
    match fs::read_to_string(&path) {
        Ok(content) => FileResult {
            success: true,
            content: Some(content),
            entries: None,
            error: None,
        },
        Err(e) => FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some(e.to_string()),
        },
    }
}

#[tauri::command]
fn write_file(path: String, content: String) -> FileResult {
    // Ensure parent directory exists
    if let Some(parent) = PathBuf::from(&path).parent() {
        let _ = fs::create_dir_all(parent);
    }

    match fs::write(&path, &content) {
        Ok(_) => FileResult {
            success: true,
            content: None,
            entries: None,
            error: None,
        },
        Err(e) => FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some(e.to_string()),
        },
    }
}

#[tauri::command]
fn list_dir(path: String) -> FileResult {
    match fs::read_dir(&path) {
        Ok(entries) => {
            let mut file_entries = Vec::new();
            for entry in entries.flatten() {
                let file_type = entry.file_type().ok();
                file_entries.push(FileEntry {
                    name: entry.file_name().to_string_lossy().to_string(),
                    is_directory: file_type.map(|t| t.is_dir()).unwrap_or(false),
                    path: entry.path().to_string_lossy().to_string(),
                });
            }
            // Sort: directories first, then alphabetically
            file_entries.sort_by(|a, b| {
                b.is_directory
                    .cmp(&a.is_directory)
                    .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
            });
            FileResult {
                success: true,
                content: None,
                entries: Some(file_entries),
                error: None,
            }
        }
        Err(e) => FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some(e.to_string()),
        },
    }
}

// ── Aether Runtime ─────────────────────────────────────────────────

/// Find the aether binary — checks PATH, ~/.local/bin, common install locations
fn find_aether() -> Option<String> {
    // Check PATH first
    if which::which("aether").is_ok() {
        return Some("aether".to_string());
    }
    // Check common install locations
    let candidates = [
        format!("{}/.local/bin/aether", std::env::var("HOME").unwrap_or_default()),
        "/usr/local/bin/aether".to_string(),
        "/usr/bin/aether".to_string(),
    ];
    for path in &candidates {
        if std::path::Path::new(path).exists() {
            return Some(path.clone());
        }
    }
    None
}

/// Find ollama binary
fn find_ollama() -> Option<String> {
    if which::which("ollama").is_ok() {
        return Some("ollama".to_string());
    }
    let candidates = [
        "/usr/local/bin/ollama".to_string(),
        "/usr/bin/ollama".to_string(),
    ];
    for path in &candidates {
        if std::path::Path::new(path).exists() {
            return Some(path.clone());
        }
    }
    None
}

#[derive(Debug, Serialize)]
struct SetupStatus {
    aether_installed: bool,
    aether_path: Option<String>,
    ollama_installed: bool,
    ollama_running: bool,
    model_available: bool,
    model_name: String,
    all_ready: bool,
}

#[tauri::command]
fn check_setup(model_name: String) -> SetupStatus {
    let aether = find_aether();
    let ollama = find_ollama();
    let ollama_running = std::process::Command::new("ollama")
        .arg("list")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    let model_available = if ollama_running {
        std::process::Command::new("ollama")
            .args(["list"])
            .output()
            .map(|o| {
                String::from_utf8_lossy(&o.stdout)
                    .contains(&model_name)
            })
            .unwrap_or(false)
    } else {
        false
    };

    let has_aether = aether.is_some();

    SetupStatus {
        aether_installed: has_aether,
        aether_path: aether,
        ollama_installed: ollama.is_some(),
        ollama_running,
        model_available,
        model_name,
        all_ready: has_aether && ollama_running && model_available,
    }
}

#[tauri::command]
fn run_aether(path: String, debug: bool, state: State<ForgeState>) -> FileResult {
    if let Ok(mut proc) = state.aether_process.lock() {
        if let Some(ref mut child) = *proc { let _ = child.kill(); }
    }

    let aether_bin = match find_aether() {
        Some(p) => p,
        None => return FileResult {
            success: false, content: None, entries: None,
            error: Some("Aether is not installed.\n\nInstall it:\n  curl -fsSL https://raw.githubusercontent.com/StratosLabs-Aether/source/main/aether-native/install.sh | bash".to_string()),
        },
    };

    let mut cmd = std::process::Command::new(&aether_bin);
    if debug { cmd.arg("--debug"); }
    cmd.arg(&path);
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());
    cmd.stdin(std::process::Stdio::piped());

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => return FileResult {
            success: false, content: None, entries: None,
            error: Some(format!("Could not run aether: {}. Install it?", e)),
        },
    };

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    let stdin = child.stdin.take();

    // Store process handle for stop button
    if let Ok(mut proc) = state.aether_process.lock() {
        *proc = Some(child);
    }

    // Reset terminal state
    let term = state.terminal.clone();
    {
        let mut t = term.lock().unwrap();
        t.output.clear();
        t.done = false;
        t.exit_code = None;
        t.stdin = stdin;
    }

    // Spawn reader threads
    use std::io::Read;
    if let Some(mut out) = stdout {
        let term = term.clone();
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match out.read(&mut buf) {
                    Ok(0) => break,
                    Ok(n) => {
                        let mut t = term.lock().unwrap();
                        t.output.extend_from_slice(&buf[..n]);
                    }
                    Err(_) => break,
                }
            }
        });
    }
    if let Some(mut err) = stderr {
        let term = term.clone();
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match err.read(&mut buf) {
                    Ok(0) => break,
                    Ok(n) => {
                        let mut t = term.lock().unwrap();
                        t.output.extend_from_slice(&buf[..n]);
                    }
                    Err(_) => break,
                }
            }
        });
    }

    // Wait for process in background
    if let Ok(mut proc) = state.aether_process.lock() {
        if let Some(ref mut child) = *proc {
            let term = term.clone();
            // Can't move child out of mutex, so we track via state
            std::thread::spawn(move || {
                // The child is in the state mutex — we wait via the stored handle
                // For now, just mark done after a delay (the stop button handles kill)
            });
        }
    }

    FileResult {
        success: true,
        content: Some("started".to_string()),
        entries: None,
        error: None,
    }
}

#[tauri::command]
fn terminal_read(state: State<ForgeState>) -> FileResult {
    let mut term = state.terminal.lock().unwrap();
    let text = String::from_utf8_lossy(&term.output).to_string();
    let exit = term.exit_code;
    // Check if process is done
    if !term.done {
        if let Ok(mut proc) = state.aether_process.lock() {
            if let Some(ref mut child) = *proc {
                match child.try_wait() {
                    Ok(Some(status)) => {
                        term.done = true;
                        term.exit_code = status.code();
                    }
                    Ok(None) => {} // still running
                    Err(_) => { term.done = true; }
                }
            } else {
                term.done = true;
            }
        }
    }
    let done = term.done;
    let exit_code = term.exit_code;
    drop(term);
    FileResult {
        success: true,
        content: Some(text),
        entries: None,
        error: if done { exit_code.map(|c| format!("exit: {}", c)) } else { None },
    }
}

#[tauri::command]
fn terminal_write(text: String, state: State<ForgeState>) -> FileResult {
    let mut term = state.terminal.lock().unwrap();
    if let Some(ref mut stdin) = term.stdin {
        use std::io::Write;
        let line = format!("{}\n", text);
        match stdin.write_all(line.as_bytes()) {
            Ok(_) => FileResult { success: true, content: None, entries: None, error: None },
            Err(e) => FileResult { success: false, content: None, entries: None, error: Some(e.to_string()) },
        }
    } else {
        FileResult { success: false, content: None, entries: None, error: Some("No running process".to_string()) }
    }
}

#[tauri::command]
fn terminal_clear(state: State<ForgeState>) -> FileResult {
    let mut term = state.terminal.lock().unwrap();
    term.output.clear();
    FileResult { success: true, content: None, entries: None, error: None }
}

#[tauri::command]
fn stop_execution(state: State<ForgeState>) -> FileResult {
    if let Ok(mut proc) = state.aether_process.lock() {
        if let Some(ref mut child) = *proc {
            let _ = child.kill();
            *proc = None;
        }
    }
    FileResult {
        success: true,
        content: None,
        entries: None,
        error: None,
    }
}

// ── Scrible AI (Ollama bridge) ─────────────────────────────────────

#[tauri::command]
async fn scrible_complete(query: ScribleQuery) -> ScribleResult {
    let client = reqwest::Client::new();
    let url = format!("{}/api/generate", query.endpoint);

    // FIM format for StarCoder2
    let fim_prefix = "<fim_prefix>";
    let _fim_suffix = "<fim_suffix>";
    let fim_middle = "<fim_middle>";

    // If the prompt contains FIM markers, use as-is; otherwise wrap
    let prompt = if query.prompt.contains(fim_prefix) {
        query.prompt
    } else {
        format!("{}{}{}{}", fim_prefix, query.prompt, fim_middle, "")
    };

    let body = serde_json::json!({
        "model": query.model,
        "prompt": prompt,
        "stream": false,
        "options": {
            "num_predict": query.max_tokens,
            "temperature": query.temperature,
            "top_p": 0.95,
            "stop": ["<|endoftext|>", "<fim_prefix>", "<fim_suffix>", "\n\n\n"]
        }
    });

    match client.post(&url).json(&body).timeout(std::time::Duration::from_secs(10)).send().await {
        Ok(resp) => {
            match resp.json::<serde_json::Value>().await {
                Ok(json) => {
                    let text = json["response"].as_str().unwrap_or("").to_string();
                    ScribleResult {
                        success: true,
                        response: Some(text),
                        error: None,
                    }
                }
                Err(e) => ScribleResult {
                    success: false,
                    response: None,
                    error: Some(format!("Parse error: {}", e)),
                },
            }
        }
        Err(e) => ScribleResult {
            success: false,
            response: None,
            error: Some(format!("Ollama unreachable: {}", e)),
        },
    }
}

#[tauri::command]
async fn scrible_chat(query: ScribleChatQuery) -> ScribleResult {
    let client = reqwest::Client::new();
    let url = format!("{}/api/chat", query.endpoint);

    let body = serde_json::json!({
        "model": query.model,
        "messages": query.messages,
        "stream": false,
        "options": {
            "num_predict": query.max_tokens,
            "temperature": query.temperature,
            "top_p": 0.95,
        }
    });

    match client.post(&url).json(&body).timeout(std::time::Duration::from_secs(30)).send().await {
        Ok(resp) => {
            match resp.json::<serde_json::Value>().await {
                Ok(json) => {
                    let content = json["message"]["content"]
                        .as_str()
                        .unwrap_or("_(No response)_")
                        .to_string();
                    ScribleResult {
                        success: true,
                        response: Some(content),
                        error: None,
                    }
                }
                Err(e) => ScribleResult {
                    success: false,
                    response: None,
                    error: Some(format!("Parse error: {}", e)),
                },
            }
        }
        Err(e) => ScribleResult {
            success: false,
            response: None,
            error: Some(format!("Ollama unreachable: {}", e)),
        },
    }
}

// ── LSP Lifecycle ──────────────────────────────────────────────────

#[tauri::command]
fn start_lsp(state: State<ForgeState>) -> FileResult {
    // Check if already running
    if let Ok(proc) = state.lsp_process.lock() {
        if proc.is_some() {
            return FileResult {
                success: true,
                content: Some("LSP already running".to_string()),
                entries: None,
                error: None,
            };
        }
    }

    // Try to spawn aether-lsp
    match Command::new("aether-lsp")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => {
            if let Ok(mut proc) = state.lsp_process.lock() {
                *proc = Some(child);
            }
            FileResult {
                success: true,
                content: Some("LSP started".to_string()),
                entries: None,
                error: None,
            }
        }
        Err(e) => FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some(format!("Failed to start aether-lsp: {}. Is it installed?", e)),
        },
    }
}

#[tauri::command]
fn stop_lsp(state: State<ForgeState>) -> FileResult {
    if let Ok(mut proc) = state.lsp_process.lock() {
        if let Some(ref mut child) = *proc {
            let _ = child.kill();
            *proc = None;
        }
    }
    FileResult {
        success: true,
        content: None,
        entries: None,
        error: None,
    }
}

// ── Native Folder Dialog ──────────────────────────────────────────

#[tauri::command]
async fn open_folder_dialog(app: tauri::AppHandle) -> FileResult {
    use tauri_plugin_dialog::DialogExt;
    let result = app.dialog()
        .file()
        .blocking_pick_folder();
    match result {
        Some(path) => FileResult {
            success: true,
            content: None,
            entries: None,
            error: None,
        },
        None => FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some("No folder selected".to_string()),
        },
    }
}

// ── Scrible Setup (pull model) ────────────────────────────────────

#[tauri::command]
fn setup_scrible() -> FileResult {
    // Check if Ollama is installed
    if which::which("ollama").is_err() {
        return FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some("Ollama is not installed. Run: curl -fsSL https://ollama.com/install.sh | sh".to_string()),
        };
    }
    // Pull the Scrible model
    let output = std::process::Command::new("ollama")
        .args(["pull", "Scrible"])
        .output();
    match output {
        Ok(out) => {
            let msg = String::from_utf8_lossy(&out.stdout).to_string();
            FileResult {
                success: out.status.success(),
                content: Some(msg),
                entries: None,
                error: if out.status.success() { None } else { Some(String::from_utf8_lossy(&out.stderr).to_string()) },
            }
        }
        Err(e) => FileResult {
            success: false,
            content: None,
            entries: None,
            error: Some(format!("Failed to pull Scrible model: {}", e)),
        },
    }
}

// ── Update Checker ────────────────────────────────────────────────

#[derive(Debug, Serialize)]
struct UpdateResult {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    current_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    latest_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    download_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[tauri::command]
async fn check_forge_update() -> UpdateResult {
    let current = env!("CARGO_PKG_VERSION").to_string();
    let url = "https://api.github.com/repos/StratosLabs-Aether/forge/releases/latest";
    let client = reqwest::Client::new();
    match client
        .get(url)
        .header("Accept", "application/vnd.github+json")
        .header("User-Agent", "Aether-Forge")
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
    {
        Ok(resp) => {
            if let Ok(json) = resp.json::<serde_json::Value>().await {
                let latest = json["tag_name"].as_str().unwrap_or("").trim_start_matches('v').to_string();
                let download_url = json["html_url"].as_str().unwrap_or("").to_string();
                return UpdateResult {
                    success: true,
                    current_version: Some(current),
                    latest_version: if latest.is_empty() { None } else { Some(latest) },
                    download_url: if download_url.is_empty() { None } else { Some(download_url) },
                    error: None,
                };
            }
            UpdateResult {
                success: false,
                current_version: Some(current),
                latest_version: None,
                download_url: None,
                error: Some("Failed to parse release data".to_string()),
            }
        }
        Err(e) => UpdateResult {
            success: false,
            current_version: Some(current),
            latest_version: None,
            download_url: None,
            error: Some(format!("Update check failed: {}", e)),
        },
    }
}

// ═══════════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════════

fn main() {
    // Fix Wayland/WebKit rendering on Linux
    std::env::set_var("WEBKIT_DISABLE_COMPOSITING_MODE", "1");
    std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    std::env::set_var("GDK_BACKEND", "x11");

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .setup(|_app| {
            // Auto-start Ollama in the background if not already running
            std::thread::spawn(|| {
                // Check if ollama is installed
                if which::which("ollama").is_err() {
                    eprintln!("[Forge] Ollama not found. Install it: curl -fsSL https://ollama.com/install.sh | sh");
                    return;
                }
                let status = std::process::Command::new("ollama")
                    .arg("serve")
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .spawn();
                match status {
                    Ok(_) => {
                        println!("[Forge] Ollama service started");
                        // Pull scrible-completor (FIM code completion model)
                        std::thread::sleep(std::time::Duration::from_secs(2));
                        let pull = std::process::Command::new("ollama")
                            .args(["pull", "scrible-completor"])
                            .stdout(std::process::Stdio::null())
                            .stderr(std::process::Stdio::null())
                            .status();
                        match pull {
                            Ok(s) if s.success() => println!("[Forge] scrible-completor ready"),
                            _ => eprintln!("[Forge] Could not pull scrible-completor"),
                        }
                    }
                    Err(e) => eprintln!("[Forge] Could not start Ollama: {}. Is it installed?", e),
                }
            });
            Ok(())
        })
        .manage(ForgeState {
            aether_process: Mutex::new(None),
            lsp_process: Mutex::new(None),
            terminal: Arc::new(Mutex::new(TerminalState {
                output: Vec::new(),
                stdin: None,
                child: None,
                done: true,
                exit_code: None,
            })),
        })
        .invoke_handler(tauri::generate_handler![
            read_file,
            write_file,
            list_dir,
            run_aether,
            terminal_read,
            terminal_write,
            terminal_clear,
            stop_execution,
            scrible_complete,
            scrible_chat,
            start_lsp,
            stop_lsp,
            open_folder_dialog,
            check_setup,
            check_forge_update,
            setup_scrible,
        ])
        .run(tauri::generate_context!())
        .expect("Failed to launch Aether Forge");
}
