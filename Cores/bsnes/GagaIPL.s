; GagaEmu's SPC700 boot program (IPL), mapped at $FFC0-$FFFF while $F1 bit 7 is set.
; Clean room: written only from public descriptions of the IPL port protocol, never from Nintendo's
; bytes or a disassembly of them. scripts/spc700-asm.py assembles it into GagaIPL.inc.
;
; Protocol, as the main CPU sees it on $2140-$2143 (ports 0-3 here at $F4-$F7):
;   1. After reset the SPC700 shows $AA on port 0 and $BB on port 1.
;   2. The CPU writes the address to ports 2/3, a command to port 1 and $CC to port 0, then waits for
;      $CC to come back on port 0.
;   3. Command non-zero: a block transfer. The CPU writes each byte to port 1 and its index (from 0,
;      mod 256) to port 0, and waits for the index to come back.
;   4. To end a block the CPU writes a new address and command, and port 0 = last index + 2..+128
;      (never 0). The echo of that value acknowledges it. Command zero jumps to the address.
;
; Zero page $00/$01 holds the destination pointer and, for the last command, the jump address.
; X stays 0 from the clear loop, so JMP [!$0000+X] jumps through $00/$01.

        .org $FFC0
reset:  mov x, #$EF
        mov sp, x               ; stack at $01EF
        mov a, #$00
clear:  mov (x), a              ; clear zero page $EF down to $01
        dec x
        bne clear
        mov (x), a              ; and $00; X is now 0 for good
        mov $F4, #$AA           ; ready signal
        mov $F5, #$BB
ready:  cmp $F4, #$CC           ; wait for the first command
        bne ready
command:
        movw ya, $F6            ; address from ports 2/3
        movw $00, ya
        mov y, $F4              ; the value to acknowledge
        mov a, $F5              ; command; sets Z, the store below does not
        mov $F4, y              ; acknowledge
        bne block
        jmp [!$0000+x]          ; command 0: start execution
block:  mov y, #$00
first:  cmp y, $F4              ; a block opens with index 0
        bne first
data:   mov a, $F5
        mov $F4, y              ; echo the index once the byte is read
        mov [$00]+y, a
        inc y
        bne next
        inc $01                 ; past 256 bytes: next page
next:   cmp y, $F4              ; Y - port 0
        beq data                ; the next index
        bpl next                ; the index already echoed: still waiting
        bra command             ; port 0 ran 1 to 128 ahead: a new command

        .org $FFFE
        .word reset             ; reset vector, read by SMP::power
