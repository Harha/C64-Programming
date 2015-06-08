// Variables
.var music = LoadSid("res/music.sid")
.var image = LoadBinary("res/fairlight.kla", BF_KOALA)

// Basic upstart
.pc = $0801 "basic"
:BasicUpstart($0810)

// Memory block for program below
.pc = $0810 "program"

main:
{
		jmp prg_init

prg_init:
		jsr scr_init
		jsr music_init
		jsr image_draw
		jmp setup_irq
		
setup_irq:
		sei							// Disable maskable IRQs
		lda #%01111111
		sta $dc0d					// Interrupt control & status register
		sta $dd0d					// Stop the kernel cursor flash / keyboard update interrupt
		lda $dc0d					// Read these two registers again to negate any pending CIA IRQs
		lda $dd0d					// Otherwise, pending CIA IRQs might occur after we finish setup_irq
		lda #%00000001
		sta $d01a					// Interrupt control register
		sta $d019					// Interrupt status register
		lda #$00
		sta $d012					// Rasterline to generate interrupt at
		lda #%00111111
		sta $d011					// Screen control register
		lda #%00110101
		sta $0001					// CPU Port, turn off the BASIC and KERNAL rom, CPU now sees RAM everywhere except at $d000-$e000 (Registers of SID/VICII/etc)
		lda #<irq1
		sta $fffe					// Interrupt service routine lowbit
		lda #>irq1
		sta $ffff					// Interrupt service routine highbit
		cli							// Enable interrupts
		jmp *						// No way back to the system, ROMs are switched off, etc.

irq1:
		// Enter the interrupt safely
		pha							// Store register A in stack
		txa
		pha							// Store register X in stack
		tya
		pha							// Store register Y in stack
		
		//lda #%11111111
		//sta $d019					// Safe way of clearing the interrupt condition of the VICII
		
		// Execute code
		inc $d020
		jsr music.play
		dec $d020
		
		// Set the next interrupt routine
		ldx #<irq2
		stx $fffe
		ldx #>irq2
		stx $ffff
		lda #$c0
		sta $d012					// Rasterline to generate the interrupt at
		sec
		rol $d019
		
		// Exit the interrupt safely
		pla
		tay							// Restore register Y from stack (Stack is FIFO: First in First out)
		pla
		tax							// Restore register X from stack
		pla							// Restore register A from stack
		
		rti							// Return from the interrupt
		
irq2:
		// Enter the interrupt safely
		pha							// Store register A in stack
		txa
		pha							// Store register X in stack
		tya
		pha							// Store register Y in stack
		
		//lda #%11111111
		//sta $d019					// Safe way of clearing the interrupt condition of the VICII
		
		// Execute code
		jsr rstr_init
		
		// Set the next interrupt routine
		ldx #<irq1
		stx $fffe
		ldx #>irq1
		stx $ffff
		lda #$00
		sta $d012					// Rasterline to generate the interrupt at
		sec
		rol $d019
		
		// Exit the interrupt safely
		pla
		tay							// Restore register Y from stack (Stack is FIFO: First in First out)
		pla
		tax							// Restore register X from stack
		pla							// Restore register A from stack
		
		rti							// Return from the interrupt
		
scr_init:
		lda #%00000000
		sta $d011					// Screen mode
		lda #$00
		sta $d020					// Make the border color black
		sta $d021					// Make the screen color black
		rts
		
music_init:
		ldx #0
		ldy #0
		jsr music.init
		
rstr_init:
		ldx rstr_indx_y				// Rasterline y-position index memory
		ldy rstr_sine_y,x			// Rasterline y-position
		ldx #$00
		stx rstr_indx_c				// Rasterline current color index
		inc rstr_indx_y

rstr_render:
		lda rstr_colors,x			// Load the current rasterline color to accumulator
		cpy $d012					// Compare the value in y against current rasterline
		bne *-3						// Branch backwards 3 bytes (to cpy) if not equal
		sta $d020					// Store the current color in accumulator to the border color
		sta $d021					// Do the same for screen color
		cpx #24
		beq end						// Branch to end if the value in x is equal to #24 decimal
		inx
		iny
		jmp rstr_render
		
image_draw:
		lda #$38
		sta $d018
		lda #$d8
		sta $d016
		lda #$3b
		sta $d011
		lda #0
		sta $d020
		lda #image.getBackgroundColor()
		sta $d021
		ldx #0

!image_loop:
		.for (var i = 0; i < 4; i++)
		{
			lda colorRam + i * $100,x
			sta $d800 + i * $100,x
		}
		inx
		bne !image_loop-
		rts

end:
		rts

}

// Memory block for data below
.pc = $8000 "data"

// Temp bytes used to store/load a, x and y register values to and from while going/exiting an interrupt
tmpa:	.byte $00
tmpx:	.byte $00
tmpy:	.byte $00
tmp1:	.byte $00

rstr_colors:
		.byte $04,$04,$04,$0e,$04,$04
		.byte $0e,$0e,$04,$03,$04,$01
		.byte $01,$06,$03,$06,$0e,$0e
		.byte $06,$06,$0e,$06,$06,$06
		.byte $00

rstr_indx_c:
		.byte $00

rstr_indx_y:
		.byte $00

rstr_sine_y:
		.fill 256, 127 + 127 + round(10 * sin(toRadians(180 * i / 64)) * sin(toRadians(45 * i / 64)))

// Memory block for music below		
.pc = music.location "music" .fill music.size, music.getData(i)

// Memory blocks for image below
.pc = $0c00 "screenram"	screenRam:	.fill image.getScreenRamSize(), image.getScreenRam(i)
.pc = $1c00 "colorram"	colorRam:	.fill image.getColorRamSize(), image.getColorRam(i)
.pc = $2000 "bitmapram"	bitmapRam:	.fill image.getBitmapSize(), image.getBitmap(i)

// Print the music info while assembling
.print ""
.print "SID Data"
.print "--------"
.print "location:$"+toHexString(music.location)
.print "init:$"+toHexString(music.init)
.print "play:$"+toHexString(music.play)
.print "songs:"+music.songs
.print "startSong:"+music.startSong
.print "size:$"+toHexString(music.size)
.print "name:"+music.name
.print "author:"+music.author
.print "copyright:"+music.copyright

.print ""
.print "Additional tech data"
.print "--------------------"
.print "header:"+music.header
.print "header version:"+music.version
.print "flags:"+toBinaryString(music.flags)
.print "speed:"+toBinaryString(music.speed)
.print "startpage:"+music.startpage
.print "pagelength:"+music.pagelength