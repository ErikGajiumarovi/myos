# Makefile для MyOS - полная система с ядром на C
# =============================================================================
# ИНСТРУМЕНТЫ И ПЕРЕМЕННЫЕ
# =============================================================================

NASM = nasm
QEMU = qemu-system-x86_64
CC = i686-elf-gcc
LD = i686-elf-ld

# Проверка наличия кросс-компилятора
ifeq (, $(shell which $(CC) 2>/dev/null))
    CC = gcc
    LD = ld
    CFLAGS += -m32
    LDFLAGS += -m elf_i386
endif

# Флаги компиляции
CFLAGS = -std=gnu99 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector -fno-pic -mno-sse -mno-sse2
LDFLAGS = -T linker.ld -nostdlib

# Файлы проекта
BOOT_ASM = boot_modern.asm
STAGE2_ASM = boot_stage2.asm
KERNEL_C = kernel.c
KERNEL_H = kernel.h

BOOT_BIN = boot_modern.bin
STAGE2_BIN = boot_stage2.bin
KERNEL_OBJ = kernel.o
KERNEL_BIN = kernel.bin

IMG_FILE = modern_os.img

# =============================================================================
# ОСНОВНЫЕ ЦЕЛИ СБОРКИ
# =============================================================================

all: $(IMG_FILE)

# Сборка загрузчика
$(BOOT_BIN): $(BOOT_ASM)
	@echo "🔨 Компиляция загрузчика..."
	$(NASM) -f bin $(BOOT_ASM) -o $(BOOT_BIN)

# Сборка второго этапа
$(STAGE2_BIN): $(STAGE2_ASM)
	@echo "🔨 Компиляция второго этапа загрузчика..."
	$(NASM) -f bin $(STAGE2_ASM) -o $(STAGE2_BIN)

# Компиляция ядра C
$(KERNEL_OBJ): $(KERNEL_C) $(KERNEL_H)
	@echo "🔨 Компиляция ядра C..."
	$(CC) $(CFLAGS) -c $(KERNEL_C) -o $(KERNEL_OBJ)

# Линковка ядра
$(KERNEL_BIN): $(KERNEL_OBJ)
	@echo "🔗 Линковка ядра..."
	$(LD) $(LDFLAGS) $(KERNEL_OBJ) -o $(KERNEL_BIN)

# Создание образа диска
$(IMG_FILE): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	@echo "💾 Создание образа диска..."
	# Создаем пустой образ 10MB
	dd if=/dev/zero of=$(IMG_FILE) bs=512 count=20480 status=none
	# Записываем загрузчик в первый сектор
	dd if=$(BOOT_BIN) of=$(IMG_FILE) bs=512 count=1 conv=notrunc status=none
	# Записываем второй этап во второй сектор
	dd if=$(STAGE2_BIN) of=$(IMG_FILE) bs=512 count=1 seek=1 conv=notrunc status=none
	# Записываем ядро начиная с сектора 10
	dd if=$(KERNEL_BIN) of=$(IMG_FILE) bs=512 seek=10 conv=notrunc status=none
	@echo "✅ Образ диска создан: $(IMG_FILE)"

# =============================================================================
# ЗАПУСК И ОТЛАДКА
# =============================================================================

run: $(IMG_FILE)
	@echo "🚀 Запуск MyOS..."
	$(QEMU) -drive format=raw,file=$(IMG_FILE) \
		-m 512M \
		-cpu qemu64 \
		-machine q35

debug: $(IMG_FILE)
	@echo "🐛 Запуск MyOS в режиме отладки..."
	$(QEMU) -drive format=raw,file=$(IMG_FILE) \
		-m 512M \
		-cpu qemu64 \
		-machine q35 \
		-s -S

# =============================================================================
# УСТАНОВКА КРОСС-КОМПИЛЯТОРА (только для macOS)
# =============================================================================

install-cross-compiler:
	@echo "📦 Установка кросс-компилятора для i686-elf..."
	@echo "Это может занять некоторое время..."
	brew install i686-elf-gcc

# =============================================================================
# ОЧИСТКА
# =============================================================================

clean:
	@echo "🧹 Очистка файлов сборки..."
	rm -f *.bin *.o *.img

.PHONY: all run debug clean install-cross-compiler
