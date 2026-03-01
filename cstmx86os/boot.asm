; ============================================================
; Custom x86 Bootloader - Stage 1 (MBR)
; Author: Portfolio Project
; Assembler: NASM
; Build: nasm -f bin boot.asm -o boot.bin
; Run:  qemu-system-x86_64 -drive format=raw,file=boot.bin
; ============================================================

[BITS 16]
[ORG 0x7C00]

; ---- Constants ----
KERNEL_OFFSET  equ 0x1000      ; where stage2 is loaded
STACK_TOP      equ 0x9000
VIDEO_SEG      equ 0xB800      ; VGA text mode segment

; ============================================================
; Entry Point
; ============================================================
start:
    cli                         ; Disable interrupts during setup
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STACK_TOP
    sti                         ; Re-enable interrupts

    ; Save boot drive number (BIOS puts it in DL)
    mov [boot_drive], dl

    ; Switch to 80x25 text mode (clear screen)
    mov ax, 0x0003
    int 0x10

    ; Print welcome banner
    mov si, msg_welcome
    call print_string

    ; Load Stage 2 from disk
    mov si, msg_loading
    call print_string
    call load_stage2

    ; Enter Protected Mode
    mov si, msg_protected
    call print_string
    call enter_protected_mode

    ; Should never reach here
    jmp $

; ============================================================
; BIOS Disk Load (INT 13h)
; Loads STAGE2_SECTORS sectors at KERNEL_OFFSET
; ============================================================
STAGE2_SECTORS equ 2

load_stage2:
    mov ah, 0x02            ; BIOS read sectors
    mov al, STAGE2_SECTORS  ; Number of sectors
    mov ch, 0x00            ; Cylinder 0
    mov cl, 0x02            ; Start from sector 2 (sector 1 = this MBR)
    mov dh, 0x00            ; Head 0
    mov dl, [boot_drive]    ; Drive
    mov bx, KERNEL_OFFSET   ; ES:BX destination buffer
    int 0x13
    jc disk_error           ; Carry flag = error
    cmp al, STAGE2_SECTORS
    jne disk_error
    ret

disk_error:
    mov si, msg_disk_err
    call print_string
    hlt

; ============================================================
; Enter 32-bit Protected Mode
; ============================================================
enter_protected_mode:
    cli                     ; Disable interrupts
    lgdt [gdt_descriptor]   ; Load GDT

    ; Set PE bit (bit 0) in CR0
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    ; Far jump to flush instruction pipeline and load CS
    jmp CODE_SEG:init_pm

; ============================================================
; GDT (Global Descriptor Table)
; ============================================================
gdt_start:

gdt_null:                   ; Mandatory null descriptor
    dd 0x0
    dd 0x0

gdt_code:                   ; Code segment: base=0, limit=4GB
    dw 0xFFFF               ; Limit bits 0-15
    dw 0x0000               ; Base  bits 0-15
    db 0x00                 ; Base  bits 16-23
    db 10011010b            ; Access byte: present, ring0, code, readable
    db 11001111b            ; Flags: 4KB gran, 32-bit, limit bits 16-19
    db 0x00                 ; Base  bits 24-31

gdt_data:                   ; Data segment: base=0, limit=4GB
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b            ; Access byte: present, ring0, data, writable
    db 11001111b
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; GDT size - 1
    dd gdt_start                  ; GDT address

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; ============================================================
; 32-bit Protected Mode Initialization
; ============================================================
[BITS 32]
init_pm:
    ; Update all segment registers to data segment
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up 32-bit stack
    mov ebp, 0x90000
    mov esp, ebp

    ; Jump to Stage 2
    call KERNEL_OFFSET

    ; Halt if stage2 returns
    hlt

; ============================================================
; 16-bit Utility: Print null-terminated string via BIOS
; ============================================================
[BITS 16]
print_string:
    pusha
.loop:
    lodsb                   ; AL = [SI], SI++
    or al, al
    jz .done
    mov ah, 0x0E            ; BIOS teletype output
    mov bh, 0x00
    mov bl, 0x07            ; Light grey on black
    int 0x10
    jmp .loop
.done:
    popa
    ret

; ============================================================
; Data
; ============================================================
boot_drive:     db 0
msg_welcome:    db 13, 10, '  *** Custom x86 Bootloader v1.0 ***', 13, 10, 0
msg_loading:    db '  [*] Loading Stage 2...', 13, 10, 0
msg_protected:  db '  [*] Entering Protected Mode...', 13, 10, 0
msg_disk_err:   db '  [!] DISK ERROR - Halting.', 13, 10, 0

; ============================================================
; Boot signature (must be at byte 510-511)
; ============================================================
times 510-($-$$) db 0
dw 0xAA55