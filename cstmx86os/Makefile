## ============================================================
## Custom x86 Bootloader - Makefile
## Requirements: nasm, qemu-system-x86_64
## ============================================================

NASM       = nasm
QEMU       = qemu-system-x86_64
IMG        = bootloader.img

.PHONY: all clean run debug

all: $(IMG)

boot.bin: boot.asm
	$(NASM) -f bin $< -o $@

stage2.bin: stage2.asm
	$(NASM) -f bin $< -o $@

$(IMG): boot.bin stage2.bin
	# Create a 1.44MB floppy image filled with zeros
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	# Write MBR (boot.bin) at sector 0
	dd if=boot.bin of=$(IMG) conv=notrunc bs=512 seek=0
	# Write Stage 2 at sector 1
	dd if=stage2.bin of=$(IMG) conv=notrunc bs=512 seek=1
	@echo "Image built: $(IMG)"

run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG) -m 32M

debug: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG) -m 32M \
	        -monitor stdio -d cpu_reset -D qemu.log

clean:
	rm -f *.bin *.img qemu.log