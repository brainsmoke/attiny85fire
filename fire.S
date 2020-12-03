/*
 * Copyright (c) 2016-2020 Erik Bosman <erik@minemu.org>
 *
 * Permission  is  hereby  granted,  free  of  charge,  to  any  person
 * obtaining  a copy  of  this  software  and  associated documentation
 * files (the "Software"),  to deal in the Software without restriction,
 * including  without  limitation  the  rights  to  use,  copy,  modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the
 * Software,  and to permit persons to whom the Software is furnished to
 * do so, subject to the following conditions:
 *
 * The  above  copyright  notice  and this  permission  notice  shall be
 * included  in  all  copies  or  substantial portions  of the Software.
 *
 * THE SOFTWARE  IS  PROVIDED  "AS IS", WITHOUT WARRANTY  OF ANY KIND,
 * EXPRESS OR IMPLIED,  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY,  FITNESS  FOR  A  PARTICULAR  PURPOSE  AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM,  DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT,  TORT OR OTHERWISE,  ARISING FROM, OUT OF OR IN
 * CONNECTION  WITH THE SOFTWARE  OR THE USE  OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * (http://opensource.org/licenses/mit-license.html)
 *
 */

#include <avr/io.h>

.section .bss

/* use ALL THE MEMORY! */
#define BUFSTART ( RAMSTART )
#define BUFEND   ( RAMEND + 1 )

#define WIDTH       24
#define WIDTH_DIV8   3
#define WIDTH_DIV4   6
#define WIDTH_DIV2  12
#define HEIGHT      20
#define HEIGHT_DIV2 10

#define CELLBUF  ( BUFSTART )
#define CELLBUFEND  ( CELLBUF+WIDTH*(HEIGHT+1) )
#define CONSTANTFFFF (CELLBUFEND)

#define CLKPIN 4
#define DATAPIN 3
#define OUTDDR DDRB
#define OUTPORT PORTB

#define rX r16
#define rY r17
#define rLEFT  r18
#define rMID   r19
#define rRIGHT r20

#define rPRNG_S r21
#define rPRNG_A r22

#define rTMP    r23
#define rDATA   r24

#define rZERO r25

#define loACCUM r26
#define hiACCUM r27

#define loCELL r28
#define hiCELL r29
#define pCELL  Y

#define loLOOKUP r30
#define hiLOOKUP r31
#define pLOOKUP  Z

.macro nop2
rjmp 1f
1:
.endm

.macro nop3
nop2
nop
.endm

.macro nop4
nop2
nop2
.endm

.section .text

.global main

.org 0x0

main:

init:

ldi rZERO, 0
ldi rPRNG_S, 0xaa
ldi rPRNG_A, 0

ldi rTMP, _BV(CLKPIN) | _BV(DATAPIN)
out _SFR_IO_ADDR(OUTPORT),  rZERO
out _SFR_IO_ADDR(OUTDDR),   rTMP

clear_cells:
	ldi loCELL, lo8(CELLBUF)
	ldi hiCELL, hi8(CELLBUF)
	ldi rX, WIDTH_DIV2*(HEIGHT+1)
	0:
		st pCELL+, rZERO
		st pCELL+, rZERO
		dec rX
		brne 0b

	ldi rDATA, 0xff
	ldi loCELL, lo8(CONSTANTFFFF)
	ldi hiCELL, hi8(CONSTANTFFFF)
	st pCELL+, rDATA
	st pCELL+, rDATA

main_loop:

ca_update:

	ldi loCELL, lo8(CELLBUF)
	ldi hiCELL, hi8(CELLBUF)

	ldi rY, HEIGHT
	loop_row:

		ldi rLEFT,  0
		ldd rMID,    pCELL+WIDTH

		ldi loLOOKUP, lo8(ca_tab)
		ldi hiLOOKUP, hi8(ca_tab)
		add loLOOKUP, rMID
		adc hiLOOKUP, rZERO

		ldi rX, WIDTH-1
		loop_col:

			ldd rRIGHT,  pCELL+WIDTH+1

			add loLOOKUP, rRIGHT
			adc hiLOOKUP, rZERO

			lpm rTMP, pLOOKUP
			st pCELL+, rTMP

			sub loLOOKUP, rLEFT
			sbc hiLOOKUP, rZERO

			mov rLEFT, rMID
			mov rMID, rRIGHT

			dec rX
			brne loop_col

		lpm rTMP, pLOOKUP
		st pCELL+, rTMP

		dec rY
		brne loop_row

seed_bottom_row:

	ldi rX, WIDTH_DIV8

	prng_fill_8:

		/* https://www.avrfreaks.net/forum/tiny-fast-prng */
		mov rTMP, rPRNG_S
		lsl rTMP
		lsl rTMP
		lsl rTMP
		eor rPRNG_S, rTMP
		mov rTMP, rPRNG_S
		lsr rTMP
		lsr rTMP
		lsr rTMP
		eor rTMP, rPRNG_A
		lsr rTMP
		lsr rTMP
		eor rPRNG_S, rTMP
		inc rPRNG_A
		ldi rMID, 57
		sec
		mov rTMP, rPRNG_S
		ror rTMP
		prng_fill8_loop:
			brcc 1f
			st pCELL+, rMID
		1:	brcs 2f
			st pCELL+, rZERO
		2:	lsr rTMP
			brne prng_fill8_loop

		dec rX
		brne prng_fill_8

#unset rLEFT
#unset rMID
#unset rRIGHT
#define rRED   r18
#define rGREEN r19
#define rBLUE  r20

plot:

    ldi rX, WIDTH_DIV2*HEIGHT_DIV2*2
	ldi hiLOOKUP, hi8(cell_map)
	ldi loLOOKUP, lo8(cell_map)

	lpm loCELL, pLOOKUP+
	lpm hiCELL, pLOOKUP+

	ldi hiACCUM, 0
	ld  loACCUM, pCELL

	ldd rTMP,    pCELL+1
	add loACCUM, rTMP
	adc hiACCUM, rZERO

	ldd rTMP,    pCELL+WIDTH
	add loACCUM, rTMP
	adc hiACCUM, rZERO

	ldd rTMP,    pCELL+WIDTH+1
	add loACCUM, rTMP
	adc hiACCUM, rZERO

	breq 1f
	ldi loACCUM, 0
1:	andi loACCUM, 0xfc
	lsr loACCUM
	mov rTMP, loACCUM
	lsr loACCUM
	add loACCUM, rTMP

	ldi hiLOOKUP, hi8(palette)
	ldi loLOOKUP, lo8(palette)
	add loLOOKUP, loACCUM
	adc hiLOOKUP, rZERO
	lpm rGREEN, pLOOKUP+
	lpm rRED,   pLOOKUP+
	lpm rBLUE,  pLOOKUP+


	ldi rDATA, 0
                                     bst rGREEN, 7
                                     bld rDATA, DATAPIN
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 6
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
	pixel_loop:
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 5
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 4
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 3
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 2
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 1
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rGREEN, 0
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    nop3
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 7
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    ldi hiLOOKUP, hi8(cell_map+WIDTH_DIV2*HEIGHT_DIV2*2+2)
/* 1 */    ldi loLOOKUP, lo8(cell_map+WIDTH_DIV2*HEIGHT_DIV2*2+2)
/* 1 */    sub loLOOKUP, rX
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 6
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
nop2
/* 1 */    sbc hiLOOKUP, rZERO
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 5
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    lpm loCELL, pLOOKUP+
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 4
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    lpm hiCELL, pLOOKUP+
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 3
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    ldi hiACCUM, 0
/* 2 */    ld  loACCUM, pCELL
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 2
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    nop
/* 2 */    ldd rTMP,    pCELL+1
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 1
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    add loACCUM, rTMP
/* 2 */    ldd rTMP,    pCELL+WIDTH
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rRED, 0
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    adc hiACCUM, rZERO
/* 1 */    add loACCUM, rTMP
/* 1 */    adc hiACCUM, rZERO
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 7
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 2 */    ldd rTMP,    pCELL+WIDTH+1
/* 1 */    add loACCUM, rTMP
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 6
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    adc hiACCUM, rZERO
/* 1 */    breq 1f
/* 1 */    ldi loACCUM, 0
/*   */    1:
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 5
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    andi loACCUM, 0xfc
/* 1 */    lsr loACCUM
/* 1 */    mov rTMP, loACCUM
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 4
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    lsr loACCUM
/* 1 */    add loACCUM, rTMP
/* 1 */    ldi hiLOOKUP, hi8(palette)
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 3
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */    ldi loLOOKUP, lo8(palette)
/* 1 */    add loLOOKUP, loACCUM
/* 1 */    adc hiLOOKUP, rZERO
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 2
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    lpm rGREEN,   pLOOKUP+
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 1
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    lpm rRED, pLOOKUP+
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */                              bst rBLUE, 0
/* 1 */                              bld rDATA, DATAPIN
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 3 */    lpm rBLUE,  pLOOKUP+
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 2 */    nop2
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */                              bst rGREEN, 7
/* 1 */                              bld rDATA, DATAPIN
/* 1 */    subi rX, 2
/* out data */                                                out _SFR_IO_ADDR(OUTPORT), rDATA
/* 2 cycles */
/* 1 */	   breq 1f
/* 1 */                              bst rGREEN, 6
/* out clk  */                                                sbi _SFR_IO_ADDR(OUTPORT), CLKPIN
/* 3 cycles */
/* 1 */                              bld rDATA, DATAPIN
/* 2 */    rjmp pixel_loop
1:

ldi rY, 199
wait_outer:
ldi rX, 215
wait_inner:
dec rX
brne wait_inner
dec rY
brne wait_outer
ldi rX, 14
wait_tail:
dec rX
brne wait_tail

	rjmp main_loop

palette:

/*

for i in range(64):
    r = min(255,i*12)
    g = min(255,((i/64.)**1.5)*1024.)
    b = min(255,i*i/16)
    r = int( ( (r/255.)**2.2 ) *255 )
    g = int( ( (g/255.)**2.2 ) *255 )
    b = int( ( (b/255.)**2.2 ) *255 )
    print(f"    {g:4d},{r:4d},{b:4d},", end='')
    if i % 4 == 3:
        print()
*/
.byte       0,   0,   0,       0,   0,   0,       0,   1,   0,       0,   3,   0
.byte       0,   6,   0,       1,  10,   0,       2,  15,   0,       3,  22,   0
.byte       5,  29,   0,       8,  38,   0,      11,  48,   0,      16,  59,   0
.byte      21,  72,   0,      28,  86,   0,      36, 101,   0,      45, 118,   0
.byte      55, 136,   0,      68, 156,   0,      82, 176,   0,      98, 199,   1
.byte     116, 223,   1,     137, 248,   1,     160, 255,   2,     185, 255,   2
.byte     213, 255,   3,     244, 255,   4,     255, 255,   4,     255, 255,   5
.byte     255, 255,   6,     255, 255,   7,     255, 255,   9,     255, 255,  10
.byte     255, 255,  12,     255, 255,  13,     255, 255,  15,     255, 255,  18
.byte     255, 255,  20,     255, 255,  23,     255, 255,  25,     255, 255,  29
.byte     255, 255,  32,     255, 255,  36,     255, 255,  40,     255, 255,  44
.byte     255, 255,  49,     255, 255,  54,     255, 255,  60,     255, 255,  66
.byte     255, 255,  72,     255, 255,  79,     255, 255,  86,     255, 255,  94
.byte     255, 255, 103,     255, 255, 112,     255, 255, 121,     255, 255, 132
.byte     255, 255, 142,     255, 255, 154,     255, 255, 166,     255, 255, 179
.byte     255, 255, 193,     255, 255, 208,     255, 255, 223,     255, 255, 239

ca_tab:

/*
for i,v in enumerate( int(((i/64)**1.25)/3.7*64.) for i in range(512) ):
    print(f"{v:4d},", end='')
    if i % 16 == 15:
        print()
 */
.byte   0,   0,   0,   0,   0,   0,   0,   1,   1,   1,   1,   1,   2,   2,   2,   2
.byte   3,   3,   3,   3,   4,   4,   4,   4,   5,   5,   5,   5,   6,   6,   6,   6
.byte   7,   7,   7,   8,   8,   8,   9,   9,   9,   9,  10,  10,  10,  11,  11,  11
.byte  12,  12,  12,  13,  13,  13,  13,  14,  14,  14,  15,  15,  15,  16,  16,  16
.byte  17,  17,  17,  18,  18,  19,  19,  19,  20,  20,  20,  21,  21,  21,  22,  22
.byte  22,  23,  23,  23,  24,  24,  25,  25,  25,  26,  26,  26,  27,  27,  27,  28
.byte  28,  29,  29,  29,  30,  30,  30,  31,  31,  32,  32,  32,  33,  33,  34,  34
.byte  34,  35,  35,  35,  36,  36,  37,  37,  37,  38,  38,  39,  39,  39,  40,  40
.byte  41,  41,  41,  42,  42,  43,  43,  43,  44,  44,  45,  45,  46,  46,  46,  47
.byte  47,  48,  48,  48,  49,  49,  50,  50,  50,  51,  51,  52,  52,  53,  53,  53
.byte  54,  54,  55,  55,  56,  56,  56,  57,  57,  58,  58,  59,  59,  59,  60,  60
.byte  61,  61,  62,  62,  63,  63,  63,  64,  64,  65,  65,  66,  66,  66,  67,  67
.byte  68,  68,  69,  69,  70,  70,  70,  71,  71,  72,  72,  73,  73,  74,  74,  75
.byte  75,  75,  76,  76,  77,  77,  78,  78,  79,  79,  80,  80,  80,  81,  81,  82
.byte  82,  83,  83,  84,  84,  85,  85,  86,  86,  86,  87,  87,  88,  88,  89,  89
.byte  90,  90,  91,  91,  92,  92,  93,  93,  94,  94,  94,  95,  95,  96,  96,  97
.byte  97,  98,  98,  99,  99, 100, 100, 101, 101, 102, 102, 103, 103, 104, 104, 105
.byte 105, 106, 106, 107, 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112
.byte 113, 113, 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120
.byte 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126, 127, 127, 128, 128
.byte 129, 129, 130, 130, 131, 131, 132, 132, 133, 133, 134, 134, 135, 135, 136, 136
.byte 137, 137, 138, 138, 139, 140, 140, 141, 141, 142, 142, 143, 143, 144, 144, 145
.byte 145, 146, 146, 147, 147, 148, 148, 149, 149, 150, 150, 151, 151, 152, 152, 153
.byte 154, 154, 155, 155, 156, 156, 157, 157, 158, 158, 159, 159, 160, 160, 161, 161
.byte 162, 162, 163, 164, 164, 165, 165, 166, 166, 167, 167, 168, 168, 169, 169, 170
.byte 170, 171, 172, 172, 173, 173, 174, 174, 175, 175, 176, 176, 177, 177, 178, 178
.byte 179, 180, 180, 181, 181, 182, 182, 183, 183, 184, 184, 185, 186, 186, 187, 187
.byte 188, 188, 189, 189, 190, 190, 191, 192, 192, 193, 193, 194, 194, 195, 195, 196
.byte 196, 197, 198, 198, 199, 199, 200, 200, 201, 201, 202, 203, 203, 204, 204, 205
.byte 205, 206, 206, 207, 207, 208, 209, 209, 210, 210, 211, 211, 212, 213, 213, 214
.byte 214, 215, 215, 216, 216, 217, 218, 218, 219, 219, 220, 220, 221, 221, 222, 223
.byte 223, 224, 224, 225, 225, 226, 227, 227, 228, 228, 229, 229, 230, 231, 231, 232

.fill 256, 1, 232

cell_map:

/*
h,w=10,12
d = [0]*(h*w)
for y in range(h):
    for x in range(w):
        if x&1:
            d[h*x+y] = y*w*4+x*2
        else:
            d[h*(x+1)-1-y] = y*w*4+x*2

for i in range(0, w*h, 6):
        print(".word "+", ".join(f"CELLBUF+{x:4d}" for x in d[i:i+6]))

 */

.word CELLBUF+ 432, CELLBUF+ 384, CELLBUF+ 336, CELLBUF+ 288, CELLBUF+ 240, CELLBUF+ 192
.word CELLBUF+ 144, CELLBUF+  96, CELLBUF+  48, CELLBUF+   0, CELLBUF+   2, CELLBUF+  50
.word CELLBUF+  98, CELLBUF+ 146, CELLBUF+ 194, CELLBUF+ 242, CELLBUF+ 290, CELLBUF+ 338
.word CELLBUF+ 386, CELLBUF+ 434, CELLBUF+ 436, CELLBUF+ 388, CELLBUF+ 340, CELLBUF+ 292
.word CELLBUF+ 244, CELLBUF+ 196, CELLBUF+ 148, CELLBUF+ 100, CELLBUF+  52, CELLBUF+   4
.word CELLBUF+   6, CELLBUF+  54, CELLBUF+ 102, CELLBUF+ 150, CELLBUF+ 198, CELLBUF+ 246
.word CELLBUF+ 294, CELLBUF+ 342, CELLBUF+ 390, CELLBUF+ 438, CELLBUF+ 440, CELLBUF+ 392
.word CELLBUF+ 344, CELLBUF+ 296, CELLBUF+ 248, CELLBUF+ 200, CELLBUF+ 152, CELLBUF+ 104
.word CELLBUF+  56, CELLBUF+   8, CELLBUF+  10, CELLBUF+  58, CELLBUF+ 106, CELLBUF+ 154
.word CELLBUF+ 202, CELLBUF+ 250, CELLBUF+ 298, CELLBUF+ 346, CELLBUF+ 394, CELLBUF+ 442
.word CELLBUF+ 444, CELLBUF+ 396, CELLBUF+ 348, CELLBUF+ 300, CELLBUF+ 252, CELLBUF+ 204
.word CELLBUF+ 156, CELLBUF+ 108, CELLBUF+  60, CELLBUF+  12, CELLBUF+  14, CELLBUF+  62
.word CELLBUF+ 110, CELLBUF+ 158, CELLBUF+ 206, CELLBUF+ 254, CELLBUF+ 302, CELLBUF+ 350
.word CELLBUF+ 398, CELLBUF+ 446, CELLBUF+ 448, CELLBUF+ 400, CELLBUF+ 352, CELLBUF+ 304
.word CELLBUF+ 256, CELLBUF+ 208, CELLBUF+ 160, CELLBUF+ 112, CELLBUF+  64, CELLBUF+  16
.word CELLBUF+  18, CELLBUF+  66, CELLBUF+ 114, CELLBUF+ 162, CELLBUF+ 210, CELLBUF+ 258
.word CELLBUF+ 306, CELLBUF+ 354, CELLBUF+ 402, CELLBUF+ 450, CELLBUF+ 452, CELLBUF+ 404
.word CELLBUF+ 356, CELLBUF+ 308, CELLBUF+ 260, CELLBUF+ 212, CELLBUF+ 164, CELLBUF+ 116
.word CELLBUF+  68, CELLBUF+  20, CELLBUF+  22, CELLBUF+  70, CELLBUF+ 118, CELLBUF+ 166
.word CELLBUF+ 214, CELLBUF+ 262, CELLBUF+ 310, CELLBUF+ 358, CELLBUF+ 406, CELLBUF+ 454
/* super hacky: averaging the four cells:
 * (cells[x]+cells[x+1]+cells[x+WIDTH]+cells[x+WIDTH+1] => ? + ? + 0xff + 0xff -> leads to a pallette value of 0
 * which means the last data value written (one beyond the last pixel) will be a 0, 
 * so the frame ends with the data (and clock) pins pulled to ground.
 */
.word CONSTANTFFFF-WIDTH


