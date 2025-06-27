[BITS 16]
[ORG 0x1000]    ; Второй этап загружается по адресу 0x1000

; Второй этап загрузчика
; Задача: переключиться в защищенный режим и загрузить ядро на C

stage2_start:
    ; Инициализация
    cli
    cld

    ; Печатаем сообщение о запуске второго этапа
    mov si, stage2_msg
    call print_16

    ; Включаем линию A20 (необходимо для доступа к памяти выше 1MB)
    call enable_a20

    ; Загружаем GDT (Global Descriptor Table)
    lgdt [gdt_descriptor]

    ; Переключаемся в защищенный режим
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Дальний переход для очистки конвейера и переключения в 32-битный режим
    jmp CODE_SEG:protected_mode_start

; Функция для печати в 16-битном режиме
print_16:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_16
.done:
    ret

; Включение линии A20
enable_a20:
    ; Метод через клавиатурный контроллер
    call a20_wait
    mov al, 0xAD
    out 0x64, al

    call a20_wait
    mov al, 0xD0
    out 0x64, al

    call a20_wait2
    in al, 0x60
    push eax

    call a20_wait
    mov al, 0xD1
    out 0x64, al

    call a20_wait
    pop eax
    or al, 2
    out 0x60, al

    call a20_wait
    mov al, 0xAE
    out 0x64, al

    call a20_wait
    ret

a20_wait:
    in al, 0x64
    test al, 2
    jnz a20_wait
    ret

a20_wait2:
    in al, 0x64
    test al, 1
    jz a20_wait2
    ret

[BITS 32]
protected_mode_start:
    ; Устанавливаем сегментные регистры для защищенного режима
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000    ; Стек в верхней части низкой памяти

    ; Печатаем сообщение в защищенном режиме
    mov esi, protected_msg
    call print_32

    ; Загружаем ядро C с диска (сектор 10)
    call load_kernel

    ; Переходим к ядру
    call 0x10000       ; Адрес, куда загружено ядро C

    ; Бесконечный цикл (если ядро вернется)
    jmp $

; Загрузка ядра с диска (в защищенном режиме нужно переключиться обратно в реальный режим)
load_kernel:
    ; Простая версия - предполагаем что ядро уже загружено
    ; В реальной реализации нужно переключиться в реальный режим для BIOS calls
    ret

; Функция печати в 32-битном режиме
print_32:
    pusha
    mov edx, 0xB8000   ; Видеопамять VGA

.loop:
    lodsb
    test al, al
    jz .done

    mov [edx], al      ; Символ
    mov byte [edx + 1], 0x07  ; Атрибуты (белый на черном)
    add edx, 2
    jmp .loop

.done:
    popa
    ret

; GDT (Global Descriptor Table)
gdt_start:
    ; Нулевой дескриптор (обязательный)
    dd 0x0
    dd 0x0

gdt_code:
    ; Дескриптор кода
    dw 0xFFFF       ; Лимит 0-15
    dw 0x0          ; База 0-15
    db 0x0          ; База 16-23
    db 10011010b    ; Флаги доступа
    db 11001111b    ; Флаги и лимит 16-19
    db 0x0          ; База 24-31

gdt_data:
    ; Дескриптор данных
    dw 0xFFFF       ; Лимит 0-15
    dw 0x0          ; База 0-15
    db 0x0          ; База 16-23
    db 10010010b    ; Флаги доступа
    db 11001111b    ; Флаги и лимит 16-19
    db 0x0          ; База 24-31

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; Константы для сегментов
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; Сообщения
stage2_msg db "Stage 2 bootloader started...", 13, 10, 0
protected_msg db "Protected mode enabled!", 0

; Заполняем до размера сектора
times 512 - ($ - $$) db 0
