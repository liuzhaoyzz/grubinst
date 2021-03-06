/*
 *  wee63start.S -- Startup code for WEE63.MBR
 *  Copyright (C) 2010  Tinybit(tinybit@tom.com)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

/*
 * This program is used to generate the wee63.mbr file.
 *
 * Use the following shell command to generate the wee63.mbr file:
 *
 * 	cat wee63start pre_stage2 > wee63.mbr
 *
 */

#define ASM_FILE
#include "shared.h"
#define ASM_FILE
	
#include "stage2_size.h"

	.file	"wee63start.S"

	.text

	.globl	start, _start

start:
_start:
_start1:

	/* Tell GAS to generate 16-bit real mode instructions */

	.code16

	. = _start1 + 0x00

	/* 1 byte at offset 0x00 will be overwritten for storing the EBIOS
	 * indicator later. This is safe because the jmp instruction only
	 * get executed once. The write happens after the jmp instruction
	 * have got executed.
	 *
	 * The value written would be 0x42 for EBIOS present(LBA) and 0x02
	 * for non-present(CHS).
	 *
	 */

	/* No cli, we use stack! BIOS or caller usually sets SS:SP=0000:0400 */

	/* Acer will hang up on USB boot if the leading byte is 0xEB(jmp).
	 * You might want to use 0x90 0x90 or 0x33 0xC0(xor AX,AX) instead.
	 */
	jmp	1f

	. = _start1 + 0x02

	.byte	0x90	/* MS uses it to indicate a valid floppy */

	. = _start1 + 0x03

	/* if the above "jmp" get changed, here it goes. */
	//jmp	1f	/* it occupies the first 2 bytes of the OEM string. */

			/* BPB of FAT can be placed here. */

	. = _start1 + 0x5A

	.byte	0x80	/* bit0=1: disable GRLDR search on floppy */
			/* bit1=1: disable the boot of the previous MBR with
			 *	   invalid partition table */
			/* bit2=1: disable the feature of unconditional
			 *	   entrance to the command-line */
			/* bit3=1: disable geometry tune */
			/* bit7=1: disable the boot of the previous MBR prior
				   to the search for GRLDR */

	/* offset 0x5B indicates a timer counter. */

	/* 0xff indicates waiting forever,
	 * other value specifies the time in seconds to wait */

	. = _start1 + 0x5B

	.byte	5

	/* a key press to wait. if AX returned from int16 equals this word,
	 * the desired action will occur. */

	. = _start1 + 0x5C

	.word	0x3920		/* the space bar */

	. = _start1 + 0x5E

	.byte	0xff	/* preferred boot drive number, 0xff for no-drive(i.e., drive not defined) */
	.byte	0xff	/* preferred partition number, 0xff for whole drive(a floppy that has no partition table) */

	. = _start1 + 0x60

1:
	cli
	xorw	%bx, %bx
	movw	%bx, %ss
	movw	$0x580, %sp		/* temp safe stack space */
	call	1f
1:
	popw	%bx			/* Instruction Pointer of 1b */
	subw	$(1b - _start1), %bx	/* CS:BX=_start1 */

	shrw	$4, %bx
	movw	%cs, %ax
	addw	%ax, %bx		/* BX:0000=_start1 */

	/* we are booted by BIOS, or whole image already loaded */

	/* Let CS:0000=_start1 */
	pushw	%bx			/* BX:0000=_start1 */

	#;pushw	$(1f - _start1)
	.byte	0x6A, (1f - _start1)

	lret
	. = . - (. - _start1) / 0x80
1:
/* begin characteristics distinguish this sector from others */
	.byte	0x8E, 0xDB		//movw	%bx, %ds
	.byte	0x68, 0xE0, 0x07	//pushw	$0x07E0
	.byte	0x07			//popw	%es	/* ES=0x07E0 */

	//cmpl	$0xCE1A02B0, (wee63_signature - _start1 + 4 + STAGE2_SIZE - 4)
	.byte	0x66, 0x81, 0x3E	//cmpl
	.word	(wee63_signature - _start1 + STAGE2_SIZE)
				//this word is a pointer to the bootlace
				//signature near the end of pre_stage2
				//this word varies according to STAGE2_SIZE.
	.byte	0xB0, 0x02, 0x1A, 0xCE	//this is the bootlace signature.
					//it should also appear at near the end
					//of pre_stage2
/* end characteristics distinguish this sector from others */
	jne	1f

	/* move image to destination 0000:8200 */

	cmpw	$0x07E0, %bx
	je	2f

	ja	3f

	/* move up */

	movw	$0xFFFC, %si
	movw	%si, %di
	movw	$0x3F00, %cx
	std
	repz movsl
	cld
	jmp	2f
3:
	/* move down */

	/* move this sector to 07C0:0000 */

	pushw	$0x07C0
	popw	%es		/* ES=0x07C0 */

	xorw	%si, %si
	xorw	%di, %di
	movw	$0x80, %cx
	cld
	repz movsl

	ljmp	$0x07C0, $(3f - _start1)
3:
	/* move pre_stage2 */

	pushw	$0x07E0
	popw	%es		/* ES=0x07E0 */

	movw	$0x400, %si
	movw	%si, %di
	movw	$0x3F00, %cx
	repz movsl
	jmp	2f
1:
	/* we are loaded by BIOS, only the MBR sector is loaded. */

	pushw	$0x07E0
	popw	%ss		/* SS=0x07E0 */
	movw	$0xF000, %sp
	sti

	pushw	%ss		/* SS=0x07E0 */
	popw	%es		/* ES=0x07E0 */
	pushw	%es
	popw	%ds		/* DS=0x07E0 */

	/* clear the destination sector */
	xorw	%ax, %ax
	xorw	%di, %di
	movw	$0x100, %cx
	cld
	repz stosw

	/* read 63 sectors of drive 0x80 or drive 0x00 to 07E0:0000 */

	movb	$0x80, %dl	/* hard drive */
1:
	xorl	%eax, %eax
	pushaw
	pushl	%eax
	pushl	%eax
	pushw	%es
	pushw	%ax
	pushw	$63
	pushw	$0x10
	movw	%sp, %si
	movw	$0x4200, %ax
	call	int13
	popaw
	popaw

	/* compare the sector to the MBR */

	xorw	%si, %si
	xorw	%di, %di
	movw	$0x100, %cx
	cs repz cmpsw
	je	1f
	testb	%dl, %dl
	je	Error_or_prev_MBR	/* Missing helper */
	movb	$0, %dl		/* floppy */
	jmp	1b
1:

	movw	%ds, %bx
	addw	$((wee63_signature - _start1 + 4 + STAGE2_SIZE - 4) >> 4), %bx
	movw	%bx, %ds

	cmpl	$0xCE1A02B0, ((STAGE2_SIZE - 4) & 0x0F)
	jne	Error_or_prev_MBR	/* Missing helper */
2:
	ljmp	$0, $0x8200

Error_or_prev_MBR:

	/* wee63 not found, launch previous MBR or print error message. */

	movw	%cs, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	movw	$0xF000, %sp

	movb	$0x80, %dl	/* hard drive */
	xorl	%eax, %eax
	movw	%ax, 0x5FE	/* clear boot signature */
	pushaw
	pushl	%eax
	incw	%ax		/* EAX=1 for prev_MBR */
	pushl	%eax
	pushw	%es
	pushw	$0x400
	pushw	%ax		/* read 1 sector */
	pushw	$0x10
	movw	%sp, %si
	movw	$0x4200, %ax
	call	int13
	popaw
	popaw

	cmpw	$0xAA55, 0x5FE
	jne	1f

	/* boot prev_MBR */

	/* move this sector up */

	xorw	%si, %si
	movw	$0x200, %di
	movw	$0x100, %cx
	cld
	repz movsw

	ljmp	$0x07E0, $(2f - _start1)
2:
	/* move prev_MBR to 0000:7C00 */

	xorw	%di, %di
	movw	$0x400, %si
	movw	$0x100, %cx
	cld
	repz movsw

	ljmp	$0x0, $0x7C00	/* boot! */

1:
	movw	$(message_string - _start1), %si

	call	print_message	/* CS:SI points to message string */
3:	jmp	3b

int13:
	pushw	%ds
	pushw	%es
//	pushw	%bx
	pushw	%dx
	pushw	%si
	pushw	%di
	pushw	%bp
	stc
	int	$0x13
	popw	%bp
	popw	%di
	popw	%si
	popw	%dx
//	popw	%bx
	popw	%es
	popw	%ds
	ret

	/* prints string CS:SI (modifies AX BX SI) */
3:
	//xorw	%bx, %bx	/* video page 0 */
	movb	$0x0e, %ah	/* print char in AL */
	int	$0x10		/* via TTY mode */

print_message:

	lodsb	%cs:(%si), %al	/* get token */
	cmpb	$0, %al		/* end of string? */
	jne	3b
	ret

message_string:

	.ascii	"\r\nUrr! wee...\0"

	/* Make sure the above code does not occupy the partition table */

	/* offset value here must be less than or equal to 0x1b8 */
	. = . - ((. - _start1) / 0x1b9)

	. = _start1 + 0x1be	/* The partition table */

	. = _start1 + 0x1fe	/* boot signature */

	.word	0xaa55

	. = _start1 + 0x200

/* if it is in the Master Boot Track, the second sector can be used to backup
 * the previously working MBR, typically, the MS MBR. if the backup copy of
 * the MBR cannot boot(because, e.g., it depends on another sector of code
 * that does not exist for now), then please do not set the ending signature
 * to 0xAA55, that is to say, if the signature is already 0xAA55, you should
 * change it to another value(for example, 0x0000).
 */

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	. = _start1 + 0x256	/* cmdcons comes here */

	.byte	0x90, 0x90

	. = _start1 + 0x258

	.byte	0x90, 0x90

	. = _start1 + 0x25a

	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90
	.byte	0x90, 0x90

	. = _start1 + 0x26a
1:
	cli
	xorw	%bx, %bx
	movw	%bx, %ss
	movw	$0x600, %sp		/* temp safe stack space */
	call	1f
1:
	popw	%bx			/* Instruction Pointer of 1b */
	subw	$(1b - _start1), %bx	/* CS:BX=_start1 */

	shrw	$4, %bx
	movw	%cs, %ax
	addw	%ax, %bx		/* BX:0000=_start1 */

	/* we are booted by BIOS, or whole image already loaded */

	/* Let CS:0000=_start1 */
	pushw	%bx			/* BX:0000=_start1 */

	pushw	$(1f - _start1)
	#;.byte	0x6A, (1f - _start1)

	lret
	//. = . - (. - _start1) / 0x80
1:
	movw	%bx, %ds

	/* print a message for BOOT.INI */
	movw	$(BOOT_INI_string - _start1), %si

	call	print_message	/* CS:SI points to message string */

	/* a value < 0x80 here means we are not booted from no-emulation-mode
	 * bootable CD.
	 */
	movb	$0x7F, %dl
	jmp	_start1

BOOT_INI_string:

	.ascii	"\r\nShould not run from BOOT.INI\r\n\0"

#if 0
wee63_real_start:

	cli
	movw	%cs, %bp	/* save CS to BP */
	call	1f
1:
	popw	%bx		/* BX=Instruction Pointer of 1b */
	subw	$(1b - _start1), %bx
	movw	%bx, %cx
	shrw	$4, %bx
	addw	%bp, %bx
	pushw	%bx		/* new CS */
	andw	$0x000f, %cx
	addw	$(1f - _start1), %cx
	pushw	%cx		/* new IP */
	lret
1:
	movw	%ds, %cx	/* CX==BP==0x7C0 for pxe enabled */
	pushw	%cs
	popw	%ds

	/* CS=DS=BX, CS:0000 = _start1 */

	addw	$((pre_stage2_start - _start1) >> 4), %bx

	/* BX:0000 = pre_stage2_start */

	cmpw	$0x7C0, %bp
	jne	1f
	cmpw	%bp, %cx
	je	2f
1:
	/* disable pxe */
	orb	$0x01, (pre_stage2_start - _start1 + 5)
2:
	cmpw	$0x820, %bx
	jb	2f

	movw	$((0x8200 - (pre_stage2_start - _start1) - 0x400) >> 4), %cx

	/* Now CS(=DS) >= CX+0x40 */

	movw	%cx, %es
	xorw	%di, %di
	xorw	%si, %si

	/////////////////////////////////////////////////////////////
	//
	//                    CS
	//                    DS          0x820     BX
	//                    _start1---------------pre_stage2_start
	//          CX+0x40---------------0x820
	//   CX
	//   ES
	//
	/////////////////////////////////////////////////////////////

	movw	$0x200, %cx	/* move 2 sectors */
	cld
	repz movsw

	pushw	%es		/* ES:0000 = _start */
	pushw	$(1f - _start)
	lret			/* CS=ES, CS:0000 = _start1 */
1:

	/* move BX:0000 to 0820:0000 upward since BX >= 0x820 */

	cld

	movw	%bx, %ds
	movw	$0x820, %bx
	movw	%bx, %es

	xorw	%si, %si
	xorw	%di, %di

	movw	$6, %bx		/* 64K pages: 0x20000 - 0x7ffff */
1:
	movw	$0x8000, %cx
	repz movsw
	movw	%ds, %ax
	addw	$0x1000, %ax
	movw	%ax, %ds
	movw	%es, %ax
	addw	$0x1000, %ax
	movw	%ax, %es
	decw	%bx
	jnz	1b

	jmp	3f
2:

	/* move BX:0000 to 0820:0000 downward since BX < 0x820 */

	std

	addw	$0x7000, %bx
	movw	%bx, %ds
	movw	$0x7820, %bx
	movw	%bx, %es

	movw	$0xfffe, %si
	movw	%si, %di

	movw	$8, %bx		/* 64K pages: 0x08200 - 0x881ff */
1:
	movw	$0x8000, %cx
	repz movsw
	movw	%ds, %ax
	subw	$0x1000, %ax
	movw	%ax, %ds
	movw	%es, %ax
	subw	$0x1000, %ax
	movw	%ax, %es
	decw	%bx
	jnz	1b

	cld

3:

	xorw	%ax, %ax
	movw	%ax, %es
	movw	%ax, %ds
	movw	%ax, %ss
	movw	$0x2000, %sp

	movw	$0x0003, %ax	/* set display mode: 80*25 color text */
	int	$0x10
	ljmp	$0, $0x8200
#endif

	. = _start1 + 0x3FC

wee63_signature:
	//.byte	0x47, 0x52, 0x55, 0xaa	/* signature for helper */

	. = _start1 + 0x400

pre_stage2_start:


