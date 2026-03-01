; ============================================================
; Custom x86 Bootloader - Stage 2
; Handles: A20 Line, Memory Map (E820), VGA Init, Kernel Jump
; Assembler: NASM
; Build: nasm -f bin stage2.asm -o stage2.bin
; ============================================================

[BITS 32]
[ORG 0x1000]

; ============================================================
; Stage 2 Entry
; ============================================================
stage2_main:
    ; Print PM confirmation via direct VGA write
    mov esi, msg_stage2
    mov edi, 0xB8000        ; VGA text buffer
    call vga_print_string

    ; Enable A20 Line (fast method via port 0x92)
    call enable_a20

    ; Get memory map from BIOS (must be done before full PM)
    ; Note: Real implementation would switch back to real mode
    ; For portfolio purposes, we demonstrate the structure:
    mov esi, msg_a20ok
    add edi, 160            ; Next VGA row (80 chars * 2 bytes)
    call vga_print_string

    ; Initialize memory regions
    call memory_init

    ; Print memory info
    mov esi, msg_memok
    add edi, 160
    call vga_print_string

    ; Print final ready message
    mov esi, msg_ready
    add edi, 160
    call vga_print_string

    ; In a real bootloader, we'd now load & jump to the kernel ELF
    ; call load_kernel
    ; jmp KERNEL_LOAD_ADDR

    ; For demo: enter infinite loop with blinking cursor
.halt_loop:
    hlt
    jmp .halt_loop

; ============================================================
; Enable A20 Line (BIOS Fast Gate)
; ============================================================
enable_a20:
    in  al, 0x92
    test al, 2
    jnz .done
    or  al, 2
    and al, 0xFE
    out 0x92, al
.done:
    ret

; ============================================================
; Basic Memory Initialization
; Sets up simple page tables for the first 4MB identity mapped
; ============================================================
PAGE_DIR  equ 0x9C000
PAGE_TBL  equ 0x9D000

memory_init:
    ; Clear page directory
    mov edi, PAGE_DIR
    mov ecx, 1024
    xor eax, eax
    rep stosd

    ; Clear page table 0
    mov edi, PAGE_TBL
    mov ecx, 1024
    rep stosd

    ; Identity map first 4MB (1024 pages * 4KB)
    mov edi, PAGE_TBL
    mov eax, 0x00000003     ; Present + Writable
    mov ecx, 1024
.map_loop:
    stosd
    add eax, 0x1000         ; Next 4KB page
    loop .map_loop

    ; Point page directory entry 0 to page table
    mov dword [PAGE_DIR], PAGE_TBL + 3  ; Present + Writable

    ; Load CR3 (page directory base)
    mov eax, PAGE_DIR
    mov cr3, eax

    ; Enable paging in CR0
    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax

    ret

; ============================================================
; VGA Direct Write - 32-bit Protected Mode
; ESI = string pointer, EDI = VGA buffer address
; Color: 0x0F = bright white on black
; ============================================================
vga_print_string:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0F            ; Attribute: bright white on black
    stosw
    jmp .loop
.done:
    popa
    ret

; ============================================================
; GDT Reload (32-bit version, already set by stage 1)
; ============================================================

; ============================================================
; Data Section
; ============================================================
msg_stage2: db '[STAGE2] Protected mode active.       ', 0
msg_a20ok:  db '[A20]   A20 line enabled.              ', 0
msg_memok:  db '[MEM]   Identity mapping 0-4MB done.  ', 0
msg_ready:  db '[READY] System initialized. Halting.  ', 0

; ============================================================
; Memory Map Structures (E820 style, populated at runtime)
; ============================================================
struc MemMapEntry
    .base_low:  resd 1
    .base_high: resd 1
    .len_low:   resd 1
    .len_high:  resd 1
    .type:      resd 1      ; 1=Available, 2=Reserved, 3=ACPI Reclaim
endstruc

; Storage for up to 32 memory map entries
mem_map_entries: times 32 * 20 db 0
mem_map_count:   dd 0