
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Установка dotfiles ===${NC}"

# Проверка, что скрипт запущен не от root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Не запускайте этот скрипт от root!${NC}"
    exit 1
fi

# Получаем директорию, где находится скрипт
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo -e "${YELLOW}Директория dotfiles: $DOTFILES_DIR${NC}"

# Функция для создания резервной копии
backup_if_exists() {
    if [ -e "$1" ]; then
        echo -e "${YELLOW}Создаём резервную копию: $1${NC}"
        mv "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# 1. Обновление системы
echo -e "${GREEN}[1/6] Обновление системы...${NC}"
sudo pacman -Syu --noconfirm

# 2. Установка основных пакетов
echo -e "${GREEN}[2/6] Установка пакетов из официальных репозиториев...${NC}"
if [ -f "$DOTFILES_DIR/pkglist.txt" ]; then
    sudo pacman -S --needed --noconfirm - < "$DOTFILES_DIR/pkglist.txt"
else
    echo -e "${RED}Файл pkglist.txt не найден!${NC}"
fi

# 3. Установка AUR helper (если ещё не установлен)
if ! command -v yay &> /dev/null; then
    echo -e "${GREEN}[3/6] Установка yay (AUR helper)...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
else
    echo -e "${YELLOW}[3/6] yay уже установлен${NC}"
fi

# 4. Установка AUR пакетов
echo -e "${GREEN}[4/6] Установка AUR пакетов...${NC}"
if [ -f "$DOTFILES_DIR/aur_pkglist.txt" ]; then
    yay -S --needed --noconfirm - < "$DOTFILES_DIR/aur_pkglist.txt"
else
    echo -e "${YELLOW}Файл aur_pkglist.txt не найден, пропускаем${NC}"
fi

# 5. Создание символических ссылок для конфигов
echo -e "${GREEN}[5/6] Создание символических ссылок...${NC}"

# Создаём необходимые директории
mkdir -p ~/.config
mkdir -p ~/.local/bin

# Функция для создания symlink
create_symlink() {
    local source="$1"
    local target="$2"
    
    if [ -e "$source" ]; then
        backup_if_exists "$target"
        ln -sf "$source" "$target"
        echo -e "${GREEN}✓${NC} Создана ссылка: $target -> $source"
    else
        echo -e "${YELLOW}⚠${NC} Не найден: $source"
    fi
}

# Конфиги
create_symlink "$DOTFILES_DIR/.config/hypr" "$HOME/.config/hypr"
create_symlink "$DOTFILES_DIR/.config/waybar" "$HOME/.config/waybar"
create_symlink "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"
create_symlink "$DOTFILES_DIR/.config/alacritty" "$HOME/.config/alacritty"
create_symlink "$DOTFILES_DIR/.config/wofi" "$HOME/.config/wofi"
create_symlink "$DOTFILES_DIR/.config/rofi" "$HOME/.config/rofi"
create_symlink "$DOTFILES_DIR/.config/dunst" "$HOME/.config/dunst"
create_symlink "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
create_symlink "$DOTFILES_DIR/.config/gtk-3.0" "$HOME/.config/gtk-3.0"
create_symlink "$DOTFILES_DIR/.config/gtk-4.0" "$HOME/.config/gtk-4.0"

# Shell конфиги
create_symlink "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Скрипты
if [ -d "$DOTFILES_DIR/scripts" ]; then
    for script in "$DOTFILES_DIR/scripts"/*; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            create_symlink "$script" "$HOME/.local/bin/$script_name"
            chmod +x "$script"
        fi
    done
fi

# 6. Финальные настройки
echo -e "${GREEN}[6/6] Финальные настройки...${NC}"

# Включение systemd сервисов (пользовательские)
echo -e "${GREEN}Включение systemd сервисов пользователя...${NC}"
while IFS= read -r service; do
    if [ -n "$service" ] && [ "$service" != "UNIT" ]; then
        systemctl --user enable "$service" 2>/dev/null || echo "Не удалось включить: $service"
    fi
done < systemd/user-enabled.txt

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo -e "${YELLOW}Рекомендуется перезагрузиться: sudo reboot${NC}"
