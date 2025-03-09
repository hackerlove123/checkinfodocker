#!/bin/bash

# Thông tin Telegram
TELEGRAM_TOKEN="7828296793:AAEw4A7NI8tVrdrcR0TQZXyOpNSPbJmbGUU"
CHAT_ID="7371969470"
POLLING_INTERVAL=7

# Hàm để gửi tin nhắn qua Telegram
send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" > /dev/null
}

# Hàm để kiểm tra lệnh từ Telegram
check_telegram_command() {
    local updates=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getUpdates")
    if echo "$updates" | grep -q "/stop"; then
        send_telegram_message "Stopping monitoring."
        pkill -f -9 monitor.sh
        exit 0
    fi
}

# Hàm để hiển thị thông tin hệ thống
display_system_info() {
    clear
    OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    RAM_INFO=$(free -k | awk '/Mem:/ {print $2, $3}')
    TOTAL_RAM_KB=$(echo $RAM_INFO | cut -d' ' -f1)
    USED_RAM_KB=$(echo $RAM_INFO | cut -d' ' -f2)
    TOTAL_RAM_GB=$(echo "scale=2; $TOTAL_RAM_KB / 1048576" | bc)
    USED_RAM_GB=$(echo "scale=2; $USED_RAM_KB / 1048576" | bc)
    FREE_RAM_GB=$(echo "scale=2; $TOTAL_RAM_GB - $USED_RAM_GB" | bc)
    RAM_USAGE_PERCENT=$(echo "scale=2; ($USED_RAM_KB / $TOTAL_RAM_KB) * 100" | bc)
    RAM_FREE_PERCENT=$(echo "scale=2; 100 - $RAM_USAGE_PERCENT" | bc)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    CPU_FREE=$(echo "scale=2; 100 - $CPU_USAGE" | bc)
    TOTAL_CORES=$(lscpu | awk '/^CPU\(s\):/ {print $2}' 2>/dev/null || echo "Không xác định")
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')
    IP_ADDRESS=$(curl -s ifconfig.me)
    
    # Kiểm tra quốc gia của IP
    COUNTRY=$(curl -s "http://ipinfo.io/$IP_ADDRESS/country")
    if [[ $COUNTRY == *"Rate limit exceeded"* ]]; then
        COUNTRY="Block Limit"
    fi

    TOP_PROCESS=$(ps -eo pid,comm,%mem,%cpu --sort=-%cpu | head -n 2 | tail -n 1)
    TOP_PID=$(echo $TOP_PROCESS | awk '{print $1}')
    TOP_CMD=$(echo $TOP_PROCESS | awk '{print $2}')
    TOP_MEM_PERCENT=$(echo $TOP_PROCESS | awk '{print $3}')
    TOP_CPU_PERCENT=$(echo $TOP_PROCESS | awk '{print $4}')
    
    # Kiểm tra sự tồn tại của lệnh lspci
    GPU_INFO=$(command -v lspci &> /dev/null && lspci | grep -i 'vga\|3d\|2d' | sed 's/^[^ ]* //;s/ (.*$//' || echo "Không xác định")

    UPTIME=$(uptime -p | sed 's/up //')

    # Tạo thông điệp
    MESSAGE="🖥 Hệ điều hành: $OS_NAME
📡 Hostname: $(hostname)
🌐 IP: $IP_ADDRESS (Quốc gia: $COUNTRY)
🏗 RAM: Tổng ${TOTAL_RAM_GB}GB | Đã dùng ${USED_RAM_GB}GB (${RAM_USAGE_PERCENT}%) | Trống ${FREE_RAM_GB}GB (${RAM_FREE_PERCENT}%)
🖥 CPU: Sử dụng ${CPU_USAGE}% | Trống ${CPU_FREE}% | Tổng số cores: $TOTAL_CORES
💾 Đĩa cứng: $DISK_USAGE
🎮 GPU: $GPU_INFO
🔍 Tiến trình tiêu tốn tài nguyên nhất: PID $TOP_PID | Lệnh: $TOP_CMD | RAM: $TOP_MEM_PERCENT% | CPU: $TOP_CPU_PERCENT%
⏳ Uptime: $UPTIME"

    # Gửi thông điệp qua Telegram
    send_telegram_message "$MESSAGE"

    echo "$MESSAGE"
    echo "----------------------------------------"
}

# Vòng lặp chính cho thông tin hệ thống
while true; do
    check_telegram_command
    display_system_info
    sleep $POLLING_INTERVAL # Gửi thông tin theo khoảng thời gian đã định
done
