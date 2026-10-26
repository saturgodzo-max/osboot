[org 0x7c00]        ; BIOS загружает бутсектор по этому адресу
bits 16             ; Использовать 16-битный реальный режим

start:
    ; Настройка сегментных регистров
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00  ; Стек растет вниз от адреса загрузки
    sti

    ; Приветственное сообщение
    mov si, msg_welcome
    call print_string

main_loop:
    ; Вывод приглашения командной строки
    mov si, msg_prompt
    call print_string

    ; Чтение строки от пользователя в буфер
    mov di, cmd_buffer
    call read_string

    ; Проверка пустой строки
    mov si, cmd_buffer
    cmp byte [si], 0
    je main_loop

    ; Сравнение команд
    mov si, cmd_buffer
    mov di, cmd_help
    call strcmp
    jc do_help

    mov si, cmd_buffer
    mov di, cmd_run
    call strcmp
    jc do_run

    mov si, cmd_buffer
    mov di, cmd_make
    call strcmp
    jc do_make

    ; Если команда не найдена
    mov si, msg_unknown
    call print_string
    jmp main_loop

do_help:
    mov si, msg_help_text
    call print_string
    jmp main_loop

do_make:
    mov si, msg_make_hint
    call print_string
    
    ; Записываем код прямо по адресу 0x8000
    mov di, 0x8000
.read_bytes:
    ; Читаем ввод пользователя (два символа Hex или 'q' для выхода)
    call read_string_silent
    cmp byte [cmd_buffer], 'q'
    je .make_done
    
    ; Преобразуем введенную ASCII-строку из двух Hex-символов в байт
    mov si, cmd_buffer
    call hex_to_byte
    stosb           ; Сохраняем байт по адресу ES:DI (0x8000+)
    
    ; Выводим точку, подтверждая ввод байта
    mov ah, 0x0e
    mov al, '.'
    int 0x10
    jmp .read_bytes

.make_done:
    mov si, msg_newline
    call print_string
    jmp main_loop

do_run:
    ; Проверяем, есть ли там хоть какой-то код (не 0)
    mov al, [0x8000]
    cmp al, 0
    je .no_prog
    
    ; Вызов программы по адресу 0x8000
    call 0x8000
    jmp main_loop
.no_prog:
    mov si, msg_no_prog
    call print_string
    jmp main_loop

; --- ФУНКЦИИ ---

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

read_string:
    xor cx, cx      ; Счетчик символов
.loop:
    xor ah, ah
    int 0x16        ; Ожидание нажатия клавиши
    
    cmp al, 0x0d    ; Enter?
    je .enter
    cmp al, 0x08    ; Backspace?
    je .backspace
    cmp cx, 63      ; Макс длина буфера
    je .loop
    
    ; Эхо-вывод символа
    mov ah, 0x0e
    int 0x10
    stosb           ; Сохранить в буфер
    inc cx
    jmp .loop
.backspace:
    jcxz .loop
    dec cx
    dec di
    mov ah, 0x0e
    mov al, 0x08    ; Двигаем курсор назад
    int 0x10
    mov al, ' '     ; Стираем символ пробелом
    int 0x10
    mov al, 0x08    ; Снова назад
    int 0x10
    jmp .loop
.enter:
    mov al, 0
    stosb           ; Терминатор строки
    mov si, msg_newline
    call print_string
    ret

read_string_silent:
    mov di, cmd_buffer
    call read_string
    ret

strcmp:
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    clc             ; CF = 0 (не равны)
    ret
.equal:
    stc             ; CF = 1 (равны)
    ret

hex_to_byte:
    ; Конвертирует 2 Hex символа из SI в байт в AL
    lodsb
    call hex_char_to_val
    shl al, 4
    mov bl, al
    lodsb
    call hex_char_to_val
    or al, bl
    ret

hex_char_to_val:
    cmp al, '0'
    jl .err
    cmp al, '9'
    jle .num
    cmp al, 'a'
    jl .err
    cmp al, 'f'
    jle .alpha
.err:
    xor al, al
    ret
.num:
    sub al, '0'
    ret
.alpha:
    sub al, 'a'
    add al, 10
    ret

; --- ДАННЫЕ ---
msg_welcome     db 'Welcome to OSboot!', 0x0d, 0x0a, 0
msg_prompt      db 'OSboot> ', 0
msg_newline     db 0x0d, 0x0a, 0
msg_unknown     db 'Unknown command.', 0x0d, 0x0a, 0
msg_help_text   db 'Commands: help, make, run', 0x0d, 0x0a, 0
msg_make_hint   db 'Enter hex bytes (e.g. b8 07 0e int 10 -> b80e07). "q" to end:', 0x0d, 0x0a, 0
msg_no_prog     db 'No program created yet.', 0x0d, 0x0a, 0

cmd_help        db 'help', 0
cmd_make        db 'make', 0
cmd_run         db 'run', 0

; Паддинг до 510 байт и сигнатура загрузчика
times 510-($-$$) db 0
dw 0xaa55

; Буфер для команд за пределами 512 байт (в памяти)
cmd_buffer:
