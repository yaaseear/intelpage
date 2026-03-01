## ============================================================
## Custom x86 Bootloader - Makefile
## Requirements: nasm, qemu-system-x86_64
## ============================================================

However the complete version isn't yet there. I am still pushing to complete it, making sure there is no error,a nd the code runs successfully everytime.
Basic description below:

Two-stage MBR bootloader from scratch. Stage 1 loads Stage 2 from disk via BIOS INT 13h and transitions the CPU from 16-bit real mode to 32-bit protected mode by building a flat GDT. Stage 2 enables the A20 line, sets up CR3 page tables for identity-mapped 4MB memory, and enables paging via CR0.