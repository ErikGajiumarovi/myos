# Инструменты
NASM = nasm
QEMU = qemu-system-x86_64

# Файлы
MODERN_ASM = boot_modern.asm
MODERN_BIN = boot_modern.bin
MODERN_IMG = modern_os.img

# Основные цели
all: modern

# Сборка современной версии
modern: $(MODERN_IMG)

$(MODERN_BIN): $(MODERN_ASM)
	$(NASM) -f bin $(MODERN_ASM) -o $(MODERN_BIN)

$(MODERN_IMG): $(MODERN_BIN)
	dd if=/dev/zero of=$(MODERN_IMG) bs=512 count=2880
	dd if=$(MODERN_BIN) of=$(MODERN_IMG) bs=512 count=1 conv=notrunc

# Запуск с настройками для современного железа
run-modern: $(MODERN_IMG)
	$(QEMU) -drive format=raw,file=$(MODERN_IMG) \
		-m 256M \
		-cpu pentium3 \
		-machine pc-i440fx-2.12 \
		-rtc base=localtime \
		-boot order=a \
		-no-reboot

# Запуск с максимальной совместимостью
run-legacy: $(MODERN_IMG)
	$(QEMU) -drive format=raw,file=$(MODERN_IMG) \
		-m 128M \
		-cpu 486 \
		-machine isapc \
		-rtc base=localtime \
		-boot order=a \
		-no-reboot

# Отладочный режим
debug-modern: $(MODERN_IMG)
	$(QEMU) -drive format=raw,file=$(MODERN_IMG) \
		-m 256M \
		-cpu pentium3 \
		-machine pc-i440fx-2.12 \
		-s -S \
		-no-reboot &
	@echo "QEMU запущен в режиме отладки"
	@echo "Подключитесь через: gdb -ex 'target remote :1234'"

# Тест на виртуальном Iron Lake (близко к i5)
run-intel: $(MODERN_IMG)
	$(QEMU) -drive format=raw,file=$(MODERN_IMG) \
		-m 512M \
		-cpu Nehalem \
		-machine q35 \
		-rtc base=localtime \
		-boot order=a \
		-no-reboot

# Создание загрузочного USB образа (для реального железа)
usb-image: $(MODERN_BIN)
	@echo "Создание USB-совместимого образа..."
	dd if=/dev/zero of=bootable_usb.img bs=1M count=16
	dd if=$(MODERN_BIN) of=bootable_usb.img bs=512 count=1 conv=notrunc
	@echo "bootable_usb.img создан (16MB)"
	@echo "ВНИМАНИЕ: Для записи на USB используйте:"
	@echo "sudo dd if=bootable_usb.img of=/dev/sdX bs=1M"
	@echo "где sdX - ваше USB устройство"

# Анализ размера
analyze: $(MODERN_BIN)
	@echo "=== АНАЛИЗ ЗАГРУЗЧИКА ==="
	@echo "Размер файла: $$(stat -f%z $(MODERN_BIN)) байт"
	@echo "Максимум: 512 байт"
	@echo "Свободно: $$((512 - $$(stat -f%z $(MODERN_BIN)))) байт"
	@hexdump -C $(MODERN_BIN) | tail -3

# Проверка инструментов
check-tools:
	@echo "=== ПРОВЕРКА ИНСТРУМЕНТОВ ==="
	@which $(NASM) && echo "✓ NASM найден" || echo "✗ NASM не найден"
	@which $(QEMU) && echo "✓ QEMU найден" || echo "✗ QEMU не найден"
	@$(NASM) -v
	@$(QEMU) --version | head -1

# Очистка
clean:
	rm -f $(MODERN_BIN) $(MODERN_IMG) bootable_usb.img
	rm -f boot.bin myos.img simple.img  # Старые файлы

# Помощь
help:
	@echo "=== ДОСТУПНЫЕ КОМАНДЫ ==="
	@echo "make modern      - Собрать современную версию"
	@echo "make run-modern  - Запуск с современными настройками"
	@echo "make run-legacy  - Запуск с максимальной совместимостью"
	@echo "make run-intel   - Эмуляция Intel архитектуры"
	@echo "make debug-modern- Запуск в режиме отладки"
	@echo "make usb-image   - Создать загрузочный USB образ"
	@echo "make analyze     - Анализ размера загрузчика"
	@echo "make check-tools - Проверка инструментов"
	@echo "make clean       - Очистка файлов"

.PHONY: all modern run-modern run-legacy debug-modern run-intel usb-image analyze check-tools clean help