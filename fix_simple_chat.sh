#!/bin/bash

# Simple Chat Plugin 自动修复脚本
# 修复流式响应显示问题
# 版本: 1.0.1
# 作者: AI Plugins Team

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 路径定义
PLUGIN_DIR="/Users/xcl/Library/Application Support/ai_plugins/plugins/simple_chat"
ORIGINAL_FILE="$PLUGIN_DIR/main.js"
BACKUP_FILE="$PLUGIN_DIR/main.js.backup"
FIXED_FILE="$(dirname "$0")/fixed_simple_chat_main.js"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_message "$GREEN" "✅ $1"
}

print_error() {
    print_message "$RED" "❌ $1"
}

print_warning() {
    print_message "$YELLOW" "⚠️  $1"
}

print_info() {
    print_message "$BLUE" "ℹ️  $1"
}

# 检查文件是否存在
check_file_exists() {
    local file_path=$1
    local description=$2

    if [[ ! -f "$file_path" ]]; then
        print_error "$description 不存在: $file_path"
        return 1
    fi
    return 0
}

# 检查目录是否存在
check_directory_exists() {
    local dir_path=$1
    local description=$2

    if [[ ! -d "$dir_path" ]]; then
        print_error "$description 目录不存在: $dir_path"
        return 1
    fi
    return 0
}

# 创建备份
create_backup() {
    print_info "创建备份文件..."

    if [[ -f "$BACKUP_FILE" ]]; then
        print_warning "备份文件已存在，将覆盖: $BACKUP_FILE"
    fi

    cp "$ORIGINAL_FILE" "$BACKUP_FILE"
    print_success "备份已创建: $BACKUP_FILE"
}

# 应用修复
apply_fix() {
    print_info "应用修复版本..."
    cp "$FIXED_FILE" "$ORIGINAL_FILE"
    print_success "修复版本已应用"
}

# 验证修复
verify_fix() {
    print_info "验证修复..."

    # 检查文件大小
    local original_size=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || echo "0")
    local fixed_size=$(stat -f%z "$ORIGINAL_FILE" 2>/dev/null || echo "0")

    if [[ "$fixed_size" -gt 0 ]]; then
        print_success "修复文件已成功写入 (大小: $fixed_size 字节)"
    else
        print_error "修复文件写入失败"
        return 1
    fi

    # 检查版本标识
    if grep -q "version.*1\.0\.1" "$ORIGINAL_FILE"; then
        print_success "修复版本标识确认 (v1.0.1)"
    else
        print_warning "未找到版本标识，但文件已更新"
    fi

    # 检查关键修复点
    if grep -q "跳过设置全局消息处理器" "$ORIGINAL_FILE"; then
        print_success "关键修复点确认：全局回调处理"
    else
        print_warning "可能存在修复不完整的情况"
    fi
}

# 显示修复后的操作指引
show_instructions() {
    echo
    print_info "修复完成！接下来的操作："
    echo
    echo "1. 重启 AI Plugins 应用"
    echo "2. 重新加载 Simple Chat 插件"
    echo "3. 发送测试消息验证流式响应"
    echo
    print_info "如果遇到问题，可以恢复备份："
    echo "   cp '$BACKUP_FILE' '$ORIGINAL_FILE'"
    echo
    print_info "查看详细修复说明："
    echo "   cat '$(dirname "$0")/SIMPLE_CHAT_FIX_GUIDE.md'"
}

# 显示脚本头部信息
show_header() {
    echo
    print_info "================================================"
    print_info "     Simple Chat Plugin 自动修复工具"
    print_info "     修复流式响应显示问题 (v1.0.1)"
    print_info "================================================"
    echo
}

# 主执行流程
main() {
    show_header

    # 检查必需文件和目录
    print_info "检查环境..."

    check_directory_exists "$PLUGIN_DIR" "插件目录" || exit 1
    check_file_exists "$ORIGINAL_FILE" "原始插件文件" || exit 1
    check_file_exists "$FIXED_FILE" "修复版本文件" || exit 1

    print_success "环境检查通过"
    echo

    # 显示当前状态
    print_info "当前插件状态："
    echo "  - 插件目录: $PLUGIN_DIR"
    echo "  - 原始文件: $(basename "$ORIGINAL_FILE")"
    echo "  - 文件大小: $(stat -f%z "$ORIGINAL_FILE" 2>/dev/null || echo "未知") 字节"

    # 检查是否已经是修复版本
    if grep -q "version.*1\.0\.1" "$ORIGINAL_FILE" 2>/dev/null; then
        print_warning "插件似乎已经是修复版本 (v1.0.1)"
        echo
        read -p "是否继续应用修复？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "操作已取消"
            exit 0
        fi
    fi

    echo
    read -p "确认开始修复？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "操作已取消"
        exit 0
    fi

    # 执行修复步骤
    echo
    print_info "开始修复流程..."

    create_backup
    apply_fix
    verify_fix

    echo
    print_success "🎉 Simple Chat 插件修复成功完成！"

    show_instructions
}

# 错误处理
trap 'print_error "修复过程中出现错误，请检查上述输出"; exit 1' ERR

# 运行主程序
main "$@"
