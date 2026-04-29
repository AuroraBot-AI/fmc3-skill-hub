#!/usr/bin/env bash
# ============================================================================
# Hugging Face 数据集 / 模型上传脚本
# ============================================================================
#
# 功能：将本地目录上传到 Hugging Face Hub，支持数据集和模型。
#
# 前置条件：
#   - 已安装 Hugging Face CLI（运行 `hf --help` 验证）
#   - 拥有 Hugging Face 账号和 Access Token
#     （首次运行时脚本会引导你登录，之后 token 会保存在本地）
#
# ============================================================================
# 使用示例
# ============================================================================
#
# 1) 最简用法 —— 上传到 FMC3-Robotic 组织（默认），仓库名取目录名：
#      bash upload2hf.sh /data/my_dataset
#      → 仓库: FMC3-Robotic/my_dataset
#
# 2) 上传到个人账号（清空 HF_ORGANIZATION）：
#      HF_ORGANIZATION="" bash upload2hf.sh /data/my_dataset
#      → 仓库: your-username/my_dataset
#
# 3) 上传到其他组织：
#      HF_ORGANIZATION=other-org bash upload2hf.sh /data/my_dataset
#      → 仓库: other-org/my_dataset
#
# 4) 自定义仓库名：
#      bash upload2hf.sh /data/my_dataset awesome-dataset
#      → 仓库: FMC3-Robotic/awesome-dataset
#
# 5) 直接在 REPO_NAME 中指定完整路径（跳过 ORGANIZATION 拼接）：
#      bash upload2hf.sh /data/my_dataset someone/awesome-dataset
#
# 6) 上传模型（脚本会自动检测，也可手动指定）：
#      bash upload2hf.sh /data/my_model
#      HF_REPO_TYPE=model bash upload2hf.sh /data/my_model
#
# 7) 创建私有仓库：
#      HF_REPO_VISIBILITY=private bash upload2hf.sh /data/my_dataset
#
# 8) 开启高性能模式（吃满网络和 CPU）：
#      HF_XET_HIGH_PERFORMANCE=1 bash upload2hf.sh /data/my_dataset
#
# 9) 组合使用 —— 私有模型仓库 + 高性能上传：
#      HF_REPO_VISIBILITY=private HF_XET_HIGH_PERFORMANCE=1 \
#        bash upload2hf.sh /data/my_model
#
# 10) 通过环境变量传入 token（适合 CI/CD，跳过交互式登录）：
#      HF_INPUT_TOKEN="hf_xxxx" bash upload2hf.sh /data/my_dataset
#
# ============================================================================

set -euo pipefail

# ============================================================================
# ========================= 用户配置区（按需修改）============================
# ============================================================================
#
# 只需修改这里的变量即可切换上传目标，其余代码无需改动。
# 所有变量都支持通过命令行参数或环境变量覆盖（见上方示例）。
#

# --- 本地目录路径 ---
# 要上传的本地目录，可以是数据集或模型目录
# 优先级：命令行第 1 个参数 > 这里的默认值
LOCAL_DIR="${1:-/path/to/your/local_folder}"

# --- 组织名（可选）---
# 填写后仓库会创建在该组织下，如 "my-org/repo_name"
# 留空则上传到个人账号下
# 优先级：环境变量 HF_ORGANIZATION > 这里的默认值
# 示例：ORGANIZATION="my-org"    → 仓库地址: my-org/repo_name
#       ORGANIZATION=""          → 仓库地址: your-username/repo_name
ORGANIZATION="${HF_ORGANIZATION:-FMC3-Robotic}"

# --- 仓库名称 ---
# Hugging Face 仓库名（不含组织前缀，组织由上面的 ORGANIZATION 控制）
# 留空则自动使用 LOCAL_DIR 的目录名
# 如果 REPO_NAME 中已包含 "org/name" 格式，则忽略 ORGANIZATION
# 优先级：命令行第 2 个参数 > 环境变量 HF_REPO_NAME > 自动取目录名
REPO_NAME="${2:-${HF_REPO_NAME:-}}"

# --- 仓库类型 ---
# 可选值：留空(自动检测) / "dataset" / "model"
# 自动检测逻辑：目录中包含 config.json、*.safetensors、*.gguf 等模型特征文件 → model
#              否则 → dataset
REPO_TYPE="${HF_REPO_TYPE:-}"

# --- 仓库可见性 ---
# 可选值："public"（公开，默认）/ "private"（私有）
REPO_VISIBILITY="${HF_REPO_VISIBILITY:-public}"

# --- 上传并发数 ---
# 默认自动检测 CPU 核数，最小 1，最大 16
# 网络带宽有限时可适当降低
MAX_WORKERS=16                        # 并发上限，可按需调整
FALLBACK_WORKERS=8                    # CPU 核数检测失败时的回退值
DEFAULT_NUM_WORKERS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
if ! [[ "$DEFAULT_NUM_WORKERS" =~ ^[0-9]+$ ]] || (( DEFAULT_NUM_WORKERS < 1 )); then
    DEFAULT_NUM_WORKERS=$FALLBACK_WORKERS
elif (( DEFAULT_NUM_WORKERS > MAX_WORKERS )); then
    DEFAULT_NUM_WORKERS=$MAX_WORKERS
fi
NUM_WORKERS="${HF_NUM_WORKERS:-$DEFAULT_NUM_WORKERS}"

# --- 上传排除规则 ---
# 上传时要排除的文件/目录 glob 模式（空格分隔）
# 示例：排除缓存目录和 .git 目录
EXCLUDE_PATTERNS=".cache/huggingface/**"

# --- 高性能模式 ---
# 设为 1/ON/YES/TRUE 时启用 xet 高性能上传（吃满网络和 CPU）
# 通过环境变量 HF_XET_HIGH_PERFORMANCE 控制，此处不直接设置

# ============================================================================
# =========================== 配置区结束 =====================================
# ============================================================================

# ---------- 内部变量（无需修改）----------
SCRIPT_NAME="$(basename "$0")"
CREATED_REPO_ID=""

# ============================================================================
# 辅助函数
# ============================================================================

# 打印使用说明
usage() {
    cat <<EOF
用法：
  $SCRIPT_NAME [LOCAL_DIR] [REPO_NAME]

行为说明：
  - 若未指定 REPO_NAME，自动使用目录名作为仓库名
  - 若未指定 HF_REPO_TYPE，自动检测目录内容判断是 dataset 还是 model
  - 首次运行且本地无 token 时，会调用 hf auth login 交互式登录
  - 登录后 token 保存在本地，后续无需再次输入

环境变量：
  HF_ORGANIZATION             组织名，设置后仓库创建在该组织下（默认: FMC3-Robotic）
                              留空则上传到个人账号: HF_ORGANIZATION=""
  HF_REPO_NAME                覆盖仓库名
  HF_REPO_TYPE                仓库类型：自动检测(默认) / dataset / model
  HF_REPO_VISIBILITY          仓库可见性：public(默认) / private
  HF_NUM_WORKERS              上传并发数，默认自动取 CPU 核数（上限 $MAX_WORKERS）
  HF_INPUT_TOKEN              首次登录时直接提供 token，跳过交互式输入
  HF_XET_HIGH_PERFORMANCE     设为 1 时开启高性能上传模式

示例：
  $SCRIPT_NAME /data/my_dataset                            # 上传到 FMC3-Robotic 组织（默认）
  HF_ORGANIZATION="" $SCRIPT_NAME /data/my_dataset         # 上传到个人账号
  HF_ORGANIZATION=other-org $SCRIPT_NAME /data/my_dataset  # 上传到其他组织
  HF_REPO_VISIBILITY=private $SCRIPT_NAME /data/my_dataset
  HF_XET_HIGH_PERFORMANCE=1 $SCRIPT_NAME /data/large_dataset
EOF
}

# 带前缀的日志输出
info() {
    echo "[upload2hf] $*"
}

# 错误输出并退出
die() {
    echo "[upload2hf] Error: $*" >&2
    exit 1
}

# 检查命令是否存在
require_command() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1（请先安装 Hugging Face CLI）"
}

# 去除 ANSI 转义序列（终端颜色代码等）
strip_ansi() {
    sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g'
}

# ============================================================================
# 仓库名清理
# ============================================================================

# 清理仓库名中的非法字符
# Hugging Face 仓库名只允许字母、数字、点(.)、下划线(_)、短横线(-)
# 输入 "my dataset!v2" → 输出 "my-dataset-v2"
sanitize_repo_name() {
    local raw="$1"
    local namespace=""
    local repo_part="$1"

    # 如果包含 "/"，拆分为 namespace/repo_part
    if [[ "$raw" == */* ]]; then
        namespace="${raw%%/*}"
        repo_part="${raw#*/}"
        # 不允许多级路径（如 a/b/c）
        [[ "$repo_part" != */* ]] || return 1
        namespace="$(sanitize_repo_segment "$namespace")" || return 1
    fi

    repo_part="$(sanitize_repo_segment "$repo_part")" || return 1
    if [[ -n "$namespace" ]]; then
        printf '%s/%s\n' "$namespace" "$repo_part"
    else
        printf '%s\n' "$repo_part"
    fi
}

# 清理仓库名中单个段的非法字符
sanitize_repo_segment() {
    local raw="$1"
    local cleaned

    # 空格 → 短横线，非法字符 → 短横线，合并连续短横线，去除首尾点和短横线
    cleaned="$(printf '%s' "$raw" | sed -E 's/[[:space:]]+/-/g; s/[^A-Za-z0-9._-]+/-/g; s/-+/-/g; s/^[.-]+//; s/[.-]+$//')"
    [[ -n "$cleaned" ]] || return 1
    printf '%s\n' "$cleaned"
}

# ============================================================================
# Token 与登录
# ============================================================================

# 获取 HF token 文件路径
resolve_token_file() {
    local hf_home
    hf_home="${HF_HOME:-$HOME/.cache/huggingface}"
    printf '%s\n' "${HF_TOKEN_PATH:-$hf_home/token}"
}

# 清除环境中的 HF_TOKEN / HUGGING_FACE_HUB_TOKEN
# 优先使用本地保存的 token，避免环境变量干扰
clear_overriding_token_env() {
    if [[ -n "${HF_TOKEN:-}" || -n "${HUGGING_FACE_HUB_TOKEN:-}" ]]; then
        info "忽略环境中的 HF_TOKEN/HUGGING_FACE_HUB_TOKEN，使用本地保存的登录凭证"
        unset HF_TOKEN || true
        unset HUGGING_FACE_HUB_TOKEN || true
    fi
}

# 首次登录（仅当本地无 token 时触发）
# 登录后 token 会保存在 ~/.cache/huggingface/token，后续无需再次输入
login_once() {
    local token_file
    local token_value

    token_file="$(resolve_token_file)"
    if [[ -s "$token_file" ]]; then
        info "已找到本地 token: $token_file"
        return
    fi

    # 优先使用环境变量中的 token（适合 CI/CD 场景）
    token_value="${HF_INPUT_TOKEN:-}"
    if [[ -z "$token_value" ]]; then
        info "未找到本地 token，需要登录（仅需一次）"
        read -r -s -p "请粘贴你的 Hugging Face token: " token_value
        echo
    fi

    [[ -n "$token_value" ]] || die "Token 为空"

    hf auth login --token "$token_value"
    [[ -s "$token_file" ]] || die "登录未生成 token 文件: $token_file"
}

# ============================================================================
# 仓库类型检测
# ============================================================================

# 自动检测目录是模型还是数据集
# 检测规则：
#   存在以下任一文件 → model
#     - config.json / adapter_config.json（模型配置）
#     - tokenizer.json / tokenizer_config.json（分词器配置）
#     - preprocessor_config.json（预处理器配置）
#     - generation_config.json（生成配置）
#     - *.safetensors / *.bin / *.gguf（模型权重文件）
#   否则 → dataset
detect_repo_type() {
    # 如果用户已手动指定，跳过检测
    if [[ -n "$REPO_TYPE" ]]; then
        return
    fi

    if [[ -f "$LOCAL_DIR/config.json" ]] \
        || [[ -f "$LOCAL_DIR/adapter_config.json" ]] \
        || [[ -f "$LOCAL_DIR/tokenizer.json" ]] \
        || [[ -f "$LOCAL_DIR/tokenizer_config.json" ]] \
        || [[ -f "$LOCAL_DIR/preprocessor_config.json" ]] \
        || [[ -f "$LOCAL_DIR/generation_config.json" ]] \
        || compgen -G "$LOCAL_DIR/*.safetensors" >/dev/null \
        || compgen -G "$LOCAL_DIR/*.bin" >/dev/null \
        || compgen -G "$LOCAL_DIR/*.gguf" >/dev/null; then
        REPO_TYPE="model"
        return
    fi

    REPO_TYPE="dataset"
}

# ============================================================================
# 仓库操作
# ============================================================================

# 生成仓库页面 URL
repo_page_url() {
    [[ -n "$CREATED_REPO_ID" ]] || return 1

    case "$REPO_TYPE" in
        dataset) printf 'https://huggingface.co/datasets/%s\n' "$CREATED_REPO_ID" ;;
        model)   printf 'https://huggingface.co/%s\n' "$CREATED_REPO_ID" ;;
        *)       return 1 ;;
    esac
}

# 校验用户输入
validate_inputs() {
    # 检查本地目录是否存在
    [[ -d "$LOCAL_DIR" ]] || die "本地目录不存在: $LOCAL_DIR"

    # 自动检测仓库类型
    detect_repo_type

    # 若未指定仓库名，使用目录名
    if [[ -z "$REPO_NAME" ]]; then
        REPO_NAME="$(basename "$LOCAL_DIR")"
    fi

    # 如果设置了 ORGANIZATION 且 REPO_NAME 中不含 "/"，自动拼接组织前缀
    # 例如：ORGANIZATION="FMC3-Robotic" + REPO_NAME="my_dataset" → "FMC3-Robotic/my_dataset"
    # 如果 REPO_NAME 已经是 "org/name" 格式，则不再拼接
    if [[ -n "$ORGANIZATION" && "$REPO_NAME" != */* ]]; then
        REPO_NAME="${ORGANIZATION}/${REPO_NAME}"
        info "使用组织: $ORGANIZATION"
    fi

    # 清理仓库名中的非法字符
    REPO_NAME="$(sanitize_repo_name "$REPO_NAME")" || die "无法生成合法仓库名: $REPO_NAME"

    # 校验仓库类型
    case "$REPO_TYPE" in
        dataset|model) ;;
        *) die "HF_REPO_TYPE 必须是 'dataset' 或 'model'，当前值: $REPO_TYPE" ;;
    esac

    # 校验可见性
    case "$REPO_VISIBILITY" in
        private|public) ;;
        *) die "HF_REPO_VISIBILITY 必须是 'private' 或 'public'，当前值: $REPO_VISIBILITY" ;;
    esac

    # 校验并发数
    [[ "$NUM_WORKERS" =~ ^[1-9][0-9]*$ ]] || die "HF_NUM_WORKERS 必须是正整数，当前值: $NUM_WORKERS"

    info "仓库类型: $REPO_TYPE | 仓库名: $REPO_NAME | 可见性: $REPO_VISIBILITY | 并发数: $NUM_WORKERS"
}

# 创建或获取远程仓库
create_or_get_repo() {
    local create_output
    local cleaned_output
    local repo_url
    local cmd

    # 构建创建仓库命令，--exist-ok 表示仓库已存在时不报错
    cmd=(hf repo create "$REPO_NAME" --repo-type "$REPO_TYPE" --exist-ok)
    if [[ "$REPO_VISIBILITY" == "private" ]]; then
        cmd+=(--private)
    fi

    # 执行创建命令
    create_output="$("${cmd[@]}" 2>&1)" || {
        printf '%s\n' "$create_output" >&2
        die "创建或访问 $REPO_TYPE 仓库失败"
    }

    printf '%s\n' "$create_output"

    # 从输出中提取仓库 URL，去除 ANSI 颜色代码后用正则匹配
    cleaned_output="$(printf '%s\n' "$create_output" | strip_ansi)"
    repo_url="$(printf '%s\n' "$cleaned_output" | sed -nE 's#.*(https://huggingface\.co(/datasets)?/[^[:space:]]+).*#\1#p' | tail -n1)"

    # 从 URL 中提取仓库 ID
    if [[ -n "$repo_url" ]]; then
        case "$REPO_TYPE" in
            dataset) CREATED_REPO_ID="${repo_url#https://huggingface.co/datasets/}" ;;
            model)   CREATED_REPO_ID="${repo_url#https://huggingface.co/}" ;;
        esac
    else
        CREATED_REPO_ID="$REPO_NAME"
    fi
}

# ============================================================================
# 上传
# ============================================================================

# 执行目录上传
upload_folder() {
    [[ -n "$CREATED_REPO_ID" ]] || die "仓库 ID 为空"

    info "正在上传 '$LOCAL_DIR' → '$CREATED_REPO_ID'（并发数: $NUM_WORKERS）"

    # 检查是否开启了高性能模式
    if [[ "${HF_XET_HIGH_PERFORMANCE:-}" =~ ^(1|ON|YES|TRUE)$ ]]; then
        info "已开启 HF_XET_HIGH_PERFORMANCE 高性能模式"
    fi

    # 使用 upload-large-folder 命令上传，适合大文件/大量文件的场景
    # --exclude 排除不需要上传的文件
    hf upload-large-folder \
        "$CREATED_REPO_ID" \
        "$LOCAL_DIR" \
        --repo-type "$REPO_TYPE" \
        --num-workers "$NUM_WORKERS" \
        --exclude "$EXCLUDE_PATTERNS"
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    # 显示帮助信息
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    require_command hf          # 1. 检查 hf 命令是否可用
    clear_overriding_token_env  # 2. 清除可能干扰的环境变量
    validate_inputs             # 3. 校验输入参数
    login_once                  # 4. 确保已登录（首次会提示输入 token）
    create_or_get_repo          # 5. 创建或获取远程仓库
    upload_folder               # 6. 上传目录到仓库

    info "上传完成!"
    info "仓库地址: $(repo_page_url)"
}

main "$@"
