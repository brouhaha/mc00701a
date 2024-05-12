; HP-IL 80-column video interface firmware
; Mountain Computer MC00701A / HP 92198A

; Copyright 2024 Eric Smith <spacewar@gmail.com>
; The original code had no US copyright

; The microprocessor is an 8039.
; The firmware is stored in U2, a 2732 EPROM or equivalent

; This source code is intended to be assembled with Macro Assembler AS.
; The "assume mb:n" pseudo-ops are required because by default AS will
; insert a bank selection automatically.

	cpu	8048

; The CRTC is a 6545A, though it appears that the special feaures of the
; 6545 (compared to similar CRTC chips) are not being used, so an MC68A45
; or HD46505 might work.

; I/O port bits:
;   P10       show display (0 = blank)
;   P11       80 col (0 = 40 col)
;   P12       char set select (1 = ASCII/inverse, 0 = Roman-8)
;   P13       cursor character select (0 = 5f underscore, 1 = 7f block)
;   P14..P17  unused
;
;   P20..P23  ADDR8..ADDR11
;   P24       HP-IL (1LB3) select, active low  (ADDR0..2 select register)
;   P25       6545 select, active low   (ADDR0 0 = address register, 1 = control register)
;                          ADDR1 is R/#W, 1 to read, 0 to write)
;   P26       display RAM select, active low
;   P27       vertical interrupt acknowledge, active low

; RAM:
;
; RB1 is the "main bank" of registers, selected most of the time. RB0 is
; for "extra" variables that can be accessed without indirection by bracketing
; access with "sel rb0" and "sel rb1".
;
;   RB0 r0 (000h) HP-IL frame control bits to send (and interrupt enable bits)
;       r1 (001h) HP-IL frame data bits to send
;       r2 (002h) interrupt saved A register
;       r3 (003h)
;       r4 (004h) parsing flags
;                 bit 0: ESC sequence flag
;                 bit 1: GOTOXY column flag
;                 bit 2: GOTOXY row flag
;		  bit 3: ?
;                 bit 4: ?
;                 bit 5: monitor mode
;       r5 (005h) status
;	   	  bit 0: width,              0 = 80 col,            1 = 40 col
;                 bit 1: char set,           0 = ASCII/inverse,     1 = Roman-8
;                 bit 2: video std,          0 = NTSC,              1 = PAL
;                 bit 3: cursor,             0 = displayed,         1 = not displayed
;                 bit 4: cursor mode,        0 = replace,           1 = insert
;                 bit 5: RAM U10 self-test:  0 = untested or good,  1 = bad
;                 bit 6: RAM U11 self-test:  0 = untested or good,  1 = bad
;                 bit 7: ???, not reported to host
;       r6 (006h) HP-IL device address (31 if no address)
;       r7 (007h) HP-IL interrupt register save
;
;
;   stack (008h..017h)
;
;   RB1 r0 (018h)  general indirection use
;       r1 (019h)  general indirection use - in HP-IL state machines, points
;                                            to the state variable
;       r2 (01ah)  HP-IL DOE remote message data bits (character being processed)
;       r3 (01bh)
;       r4 (01ch)
;       r5 (01dh)
;       r6 (01eh)
;       r7 (01fh)  HP-IL remote message C bits and chips status flags
;
; indirectly accessible variables:
;
; 020h..02dh: state machine state variables, all initialized to 0x01 (one-hot encoding)
;
; 02fh
; 030h
; 031h
; 032h
; 033h
;
; 036h
; 037h
;
; 039h
; 03ah
; 03bh
; 03ch
; 03dh
; 03eh
; 03fh
; 040h
; 041h
; 042h
; 043h
; 044h
; 045h
; 046h
; 047h
; 048h
; 049h

; For HP-IL chip (1LB3), use state machine specification in HP-IL
; Integrated Circuit User's Manual, figure 3-2, rather than that of
; HP-IL Interface Specification, figure 2-3.

hpil_sm_20_state	equ	20h
hpil_sm_20_state_01	equ	01h
hpil_sm_20_state_02	equ	02h
hpil_sm_20_state_04	equ	04h
hpil_sm_20_state_08	equ	08h

hpil_sm_21_state	equ	21h
hpil_sm_21_state_01	equ	01h
hpil_sm_21_state_02	equ	02h
hpil_sm_21_state_04	equ	04h
hpil_sm_21_state_08	equ	08h

hpil_sm_d_state	equ	22h
hpil_sm_d_state_dids	equ	01h
hpil_sm_d_state_02	equ	02h
hpil_sm_d_state_04	equ	04h
hpil_sm_d_state_08	equ	08h

hpil_sm_dc_state	equ	23h
hpil_sm_dc_state_dcis	equ	01h
hpil_sm_dc_state_dcas	equ	02h

; no state machine 24h

hpil_sm_aa_state	equ	25h		; Auto Address
hpil_sm_aa_state_aaus	equ	01h
hpil_sm_aa_state_aais	equ	02h
hpil_sm_aa_state_aacs	equ	04h
hpil_sm_aa_state_asis	equ	08h
hpil_sm_aa_state_awps	equ	10h
hpil_sm_aa_state_aecs	equ	20h

hpil_sm_lp_state	equ	26h		; Listener (primary address)
hpil_sm_lp_state_lpis	equ	01h
hpil_sm_lp_state_lpas	equ	02h

hpil_sm_l_state	equ	27h			; Listener (main)
hpil_sm_l_state_lids	equ	01h
hpil_sm_l_state_lacs	equ	02h

hpil_sm_tp_state	equ	28h		; Talker (primary address)
hpil_sm_tp_state_tpis	equ	01h
hpil_sm_tp_state_tpas	equ	02h

hpil_sm_t_state	equ	29h			; Talker (main)
hpil_sm_t_state_tids	equ	01h
hpil_sm_t_state_tads	equ	02h
hpil_sm_t_state_tacs	equ	04h
hpil_sm_t_state_spas	equ	08h
hpil_sm_t_state_dias	equ	10h
hpil_sm_t_state_aias	equ	20h
hpil_sm_t_state_ters	equ	40h
hpil_sm_t_state_tahs	equ	80h

; 2ah has three states
hpil_sm_2a_state	equ	02ah

; 2bh has four states
hpil_sm_2b_state	equ	02bh
hpil_sm_2b_state_01	equ	01h
hpil_sm_2b_state_02	equ	02h
hpil_sm_2b_state_04	equ	04h
hpil_sm_2b_state_08	equ	08h




; 6545-1 and MC6845 registers (write only unless otherwise noted)
; SY6545, SY6545-1 are mostly a superset of MC6845, except 6545-1 has no interlacing
; MPS6545-1 does not interlace or the update modes (mode reg bits 7..6, 3)
;    00h: horix total - 1          # chars
;    01h: horiz displayed          # chars
;    02h: horiz sync position      # chars
;    03h: horiz, vert sync widths  # chars (low 4), # scan lines (high 4) - MC6845 does not have vert
;    04h: vert total - 1           # char rows
;    05h: vert total adj           # scan lines
;    06h: vert displayed           # char rows
;    07h: vert sync pos            # char rows
;    08h: mode control
;         bit 7:      6545 only - update/read mode, 0 = update during sync, 1 = update during phase 1
;         bit 6:      6545 only - update strobe, 0 = pin 34 mem addr, 1 = pin 34 update strobe
;         bit 5:      6545 only - cursor skew (delay one characcter time)
;         bit 4:      6545 only - display enable skew (delay display enable on character time)
;         bit 3:      6545 only - RAM access, 0 for shared mem, 1 for transparent
;         bit 2:      6545 only - display RAM addressing, 0 = straight binary, 1 = row/column
;         bits 1..0:  X0: non-interlace
;                     01: 6545-1 invalid - 6545, 6845 interlace sync mode
;                     11: 6545-1 invalid - 6545, 6845 interlace sync and video mode
;    09h: scan lines - 1           # scan lines
;    0ah: cursor start             scan line #
;    0bh: cursor end               scan line #
;    0ch: display start addr h
;    0dh: display start addr l
;    0eh: cursor position h (r/w)
;    0fh: cursor position l (r/w)
;    10h: light pen reg h (read only)
;    11h: light pen reg l (read only)
;    12h: update address h (6545 only)
;    13h: update address l (6545 only)
;    1fh: dummy location (6545 only)


; HP-IL command messages:
hpil_cmd_nul	equ	000h	; NULl
hpil_cmd_gtl	equ	001h	; Go To Local
hpil_cmd_sdc	equ	004h	; Selected Device Clear
hpil_cmd_ppd	equ	005h	; Parallel Poll Disable
hpil_cmd_get	equ	008h	; Group Execute Trigger
hpil_cmd_eln	equ	00fh	; Enable Listener Not ready
hpil_cmd_nop	equ	010h	; No Operation (disables asynchronous request mode)
hpil_cmd_llo	equ	011h	; Local LOckout
hpil_cmd_dcl	equ	014h	; Device CLear
hpil_cmd_ppu	equ	015h	; Parallel Poll Unconfigure
hpil_cmd_ear	equ	018h	; Enable Asynchronous Requests
hpil_cmd_lad	equ	020h	; Listen ADdress n (through 03eh)
hpil_cmd_unl	equ	03fh	; UNListen
hpil_cmd_tad	equ	040h	; Talk ADdress n (through 05eh)
hpil_cmd_unt	equ	05fh	; UNTalk
hpil_cmd_sad	equ	060h	; Secondary Address n (through 07eh)
hpil_cmd_ppe0	equ	080h	; Parallel Poll Enable 0 n (through 087h)
hpil_cmd_ppe1	equ	088h	; Parallel Poll Enable 1 n (through 08fh)
hpil_cmd_ifc	equ	090h	; Interface Clear
hpil_cmd_ren	equ	092h	; Remote Enable
hpil_cmd_nre	equ	093h	; Not Remote Enable
hpil_cmd_aau	equ	09ah	; Auto Address Unconfigure
hpil_cmd_lpd	equ	09bh	; Loop Power Down
hpil_cmd_ddl	equ	0a0h	; Device Dependent Listner n (through 0bfh)
hpil_cmd_ddt	equ	0c0h	; Device Dependent Talker n (through 0dfh)

; HP-IL ready messages:
hpil_rdy_rfc	equ	000h	; Ready For Command
hpil_rdy_eto	equ	040h	; End of Transmission Ok
hpil_rdy_ete	equ	041h	; End of Transmission with Error
hpil_rdy_nrd	equ	042h	; Not Ready for Data
hpil_rdy_sda	equ	060h	; Send Data
hpil_rdy_sst	equ	061h	; Send Status
hpil_rdy_sdi	equ	062h	; Send Device Id
hpil_rdy_sai	equ	063h	; Send Accessory Identification
hpil_rdy_tct	equ	064h	; Take ConTrol
hpil_rdy_aad	equ	080h	; Auto ADdress n (through 09eh)
hpil_rdy_iaa	equ	09fh	; Illegal Auto Address
hpil_rdy_aep	equ	0a0h	; Auto Extended Primary n (through 0beh)
hpil_rdy_iep	equ	0bfh	; Illega Extended Primary
hpil_rdy_aes	equ	0c0h	; Auto Extended Secondary n (through 0deh)
hpil_rdy_ies	equ	0dfh	; Illegal Extended Secondary
hpil_rdy_amp	equ	0e0h	; Auto Multiple Primary n (through 0feh)
hpil_rdy_imp	equ	0ffh	; Illegal Multiple Primary


; HP-IL chip (1LB3) registers:
; R0 - status
;           bit 7: SC - system controller
;           bit 6: CA - controller active
;           bit 5: TA - talker active
;           bit 4; LA - listener active
;           bit 3: SSRQ - send service request
;           bit 2: RFCR (read) - RFC received
;                  SLRDY (write) - set local ready
;           bit 1: CLIFCR - clear IFCR
;           bit 0: MCL - master clear
; R1 - interrupt
;           bit 7..5: C2in (read) - control bits of received frame
;                     C2out (write) - control bits for transmission
;           bit 4: IFCR (read) - IFC received
;                       (write) - IFCR interrupt enable
;           bit 3: SRQR (read) - service request received
;                       (write) - service request received interrupt enable
;           bit 2: FRAV (read) - frame available received
;                       (write) - frame available interrupt enable
;           bit 1: FRNS (read) -  frame recieved not as sent
;                       (write) - frame recieved not as sent interrupt enable
;           bit 0: ORAV (read) - output register available
;                       (write) - output register available interrupt enable
; R2 - data
; R3 - parallel poll
;           bit 7 ORE (read) - output register empty
;           bit 6 RERR (read) - receiver error
;           bit 5 PPST - parallel poll status
;           bit 4 PPEN - parallel poll enable
;           bit 3 PPPOL - parallel poll polarity
;           bits 2..0 P2..P0 - parallel poll bit designation
; R4 - loop addrss
; R5 - scratchpad
; R6 - scratchpad
; R7 - aux read (bits 7..6) and osc disable (bit 0)


char_bs		equ	008h
char_ht		equ	009h
char_lf		equ	00ah
char_cr		equ	00dh
char_esc	equ	01bh

	org	0
	assume	mb:0

X0000:	dis	i
	jmp	X0005

	jmp	vert_intr_handler

X0005:	sel	rb1
	sel	mb1
	assume	mb:1
	call	hpil_reset_chip
	call	init_ram20
	call	hpil_set_unaddressed
	sel	mb0
	assume	mb:0
	call	display_init

main_loop:
	sel	mb1
	assume	mb:1
	call	hpil_read_intr_reg
	call	hpil_sm_20	; Receiver
	call	hpil_sm_21	; Driver
	call	hpil_sm_d	; Source Handshake
	call	hpil_sm_dc	; Device Clear
				; no state machine 24h
	call	hpil_sm_aa	; Auto Address
	call	hpil_sm_lp	; Listener (primary address)
	call	hpil_sm_l	; Listener (main)
	call	hpil_sm_tp	; Talker (primary address)
	call	hpil_sm_t	; Talker (main)

	call	hpil_clear	; handle DCL, SDC (based on DC state machine)
	sel	mb0
	assume	mb:0
	call	hpil_send_data_if_frav
	sel	mb1
	assume	mb:1
	call	X0f00		; state machine 0ah
	call	X0f44		; state machine 0bh
	sel	mb0
	assume	mb:0
	call	hpil_receive_data_if_frav
	sel	mb1
	assume	mb:1
	call	X0fac
	call	X0e14
	sel	mb0
	assume	mb:0
	jmp	main_loop


display_init:
	dis	i
	mov	a,#0feh		; 80 col, ASCII char set, replace cursor, blank display
	outl	p1,a
	mov	a,#0f0h		; deselect all hardware
	outl	p2,a

	sel	rb0
	mov	r4,#0		; clear parsing flags
	mov	r5,#80h
	sel	rb1

; set cursor to entire character height
	mov	r0,#0bh		; CRTC cursor end reg
	mov	a,#9
	call	write_crtc_control_reg

	dec	r0		; CRTC cursor start reg
	mov	a,#60h		; scan line 0 of char, and blink at 1/32 field rate
	call	write_crtc_control_reg

; init CRTC control reigsters from NTSC 80-column table
X0052:	mov	r1,#3ch		; low addr of table

; init CRTC control registers from table in page 3, low addr in r1
X0054:	mov	r5,#10		; # of CRTC registers to init
	mov	r0,#0		; start with CRTC control register 0
X0058:	mov	a,r1
	movp3	a,@a
	call	write_crtc_control_reg		; write CRTC register with addr in r0
	inc	r1
	inc	r0
	djnz	r5,X0058

	call	clear_display

; copy 16 bytes from table at 030a to registers 02eh..03dh
	mov	r0,#2eh
	mov	r1,#0ah
	mov	r5,#10h

X0068:	mov	a,r1
	movp3	a,@a
	mov	@r0,a
	inc	r0
	inc	r1
	djnz	r5,X0068
	en	i
	ret


hpil_send_data_if_frav:
	sel	mb1				; FRAV?
	assume	mb:1
	call	hpil_check_msg_non_data_and_frav
	sel	mb0
	assume	mb:0
	jz	X00af				;   no, return

	mov	r0,#hpil_sm_t_state		; TIDS?
	mov	a,@r0
	anl	a,#hpil_sm_t_state_tids
	jnz	X00af				;   yes, return

	mov	a,r2
	xrl	a,#hpil_rdy_sst
	jnz	X0091
	call	X0235
	mov	a,#80h
	call	X0200
	sel	rb0
	mov	a,r5
	sel	rb1
	anl	a,#7fh
	call	X0200
	ret

X0091:	mov	a,r2
	xrl	a,#hpil_rdy_sai
	jnz	X009d
	call	X0235
	mov	a,#32h
	call	X0200
	ret

X009d:	mov	a,r2
	xrl	a,#hpil_rdy_sdi
	jnz	X00af
	call	X0235
	mov	r5,#0ah
	mov	r1,#0
X00a8:	mov	a,r1
	movp3	a,@a
	call	X0200
	inc	r1
	djnz	r5,X00a8
X00af:	ret


; ESC N - insert mode
esc_insert_mode:
	sel	rb0
	mov	a,r5
	orl	a,#10h
	mov	r5,a
	sel	rb1
	anl	p1,#0f7h	; clear cur char sel
	ret


; ESC R - replace mode
esc_replace_mode:
	sel	rb0
	mov	a,r5
	anl	a,#0efh
	mov	r5,a
	sel	rb1
	orl	p1,#8		; set cur char sel
	ret


X00c2:	mov	r4,#20h
X00c4:	call	X029a
	mov	a,r1
	xch	a,r0
	jmp	X07f0


; ESC C - cursor right
esc_cursor_right:
	mov	r0,#3ch
	mov	a,@r0
	dec	a
	mov	@r0,a
	jnz	X00e4

	dec	r0
	mov	a,@r0
	inc	r0
	mov	@r0,a

	mov	r0,#2fh
	mov	a,@r0
	mov	r4,a
	mov	r1,#3dh
	add	a,@r1
	inc	a
	inc	r0
	inc	@r0
	xrl	a,@r0
	jnz	X00e4
	mov	a,r4
	mov	@r0,a
X00e4:	jmp	X025a


esc_cursor_left:
	mov	r0,#3bh
	mov	a,@r0
	mov	r4,a
	inc	r0
	xrl	a,@r0
	inc	@r0
	jnz	X00fd
	mov	a,r4
	mov	@r0,a
	mov	r1,#2fh
	mov	a,@r1
	inc	r1
	xrl	a,@r1
	jz	X00fd
	mov	a,@r1
	dec	a
	mov	@r1,a
	mov	@r0,#1
X00fd:	jmp	X025a


	org	100h

hpil_receive_data_if_frav:
	sel	mb1		; frame available?
	assume	mb:1
	call	hpil_check_msg_non_data_and_frns
	sel	mb0
	assume	mb:0
	jz	X0132

	mov	r0,#hpil_sm_l_state
	mov	a,@r0
	anl	a,#hpil_sm_l_state_lacs
	jz	X0132

X010d:	sel	rb0		; are we in an escape sequence?
	mov	a,r4
	sel	rb1
	jb0	X016e

	mov	a,r2
	add	a,#0e0h		; is it a control character (000h through 01fh)?
	jnc	control_char

	sel	rb0		; replace or insert mode?
	mov	a,r5
	sel	rb1
	cpl	a
	jb4	X011f		; replace mode
	jmp	X0536		; insert mode


; replace character
X011f:	mov	a,r2
	jz	X0132
	mov	r0,#34h

	dis	i
	mov	a,@r0
	mov	r1,a
	mov	a,r2
	mov	@r1,a
	inc	@r0
	mov	a,@r0
	en	i

	xrl	a,#5fh
	jnz	X0132
	clr	f1
	cpl	f1
X0132:	ret


; handle control characters
control_char:
	sel	rb0
	mov	a,r4
	anl	a,#0efh		; XXX turn off parsing flags bit 4
	mov	r4,a
	sel	rb1

	mov	a,r2
	xrl	a,#char_esc	; is the character ESC?
	jnz	X014b

; it's an ESC
	call	X07f9

	sel	rb0		; set ESC sequence flag
	mov	a,r4
	orl	a,#1
	mov	r4,a
	sel	rb1

	call	check_monitor_mode
	jnz	X011f
	ret


; not ESC
X014b:	call	check_monitor_mode
	jnz	X011f
	call	X0226
	mov	a,r2
	xrl	a,#char_cr
	jz	X0167
	mov	a,r2
	xrl	a,#char_lf
	jnz	X015d
	jmp	X02c1

X015d:	mov	a,r2
	xrl	a,#char_bs
	jnz	X0166

; char is HT (horizontal tab)
	call	X07f9
	jmp	esc_cursor_left

; char is not ESC, CR, LF
X0166:	ret


; char is CR
X0167:	mov	r0,#3bh
	mov	a,@r0
	inc	r0
	mov	@r0,a
	jmp	X025a


; in an escape sequence
X016e:	call	check_monitor_mode		; in monitor mode?
	jz	X0181		;   no

	sel	rb0		; clear ESC sequence flag
	mov	a,r4
	anl	a,#0feh
	mov	r4,a
	sel	rb1

	mov	a,r2		; was the ESC followed by Z?
	xrl	a,#'Z'
	jnz	X011f		;  no, treat as a normal character

	call	esc_clear_monitor_mode	; yes, clear monitor mode
	jmp	X011f


; in escape sequence, not in monitor mode
X0181:	sel	rb0
	mov	a,r4
	sel	rb1

	jb2	gotoxy_row	; GOTOXY row flag?
	jb1	gotoxy_column		; GOTOXY column flag?

	mov	a,r2		; is the first byte of the escape sequence a '%' (GOTOXY)?
	xrl	a,#'%'
	jnz	X0194

	sel	rb0		; set rb0_r4 bit 1 - GOTOXY column flag
	mov	a,r4
	orl	a,#2
	mov	r4,a
	sel	rb1

X0193:	ret


; ESC other than GOTOXY
X0194:	sel	rb0		; turn off escape sequence flag
	mov	a,r4
	anl	a,#0feh
	mov	r4,a
	sel	rb1

	mov	a,r2		; self test command?
	xrl	a,#'z'
	jnz	X01a1

	jmp	esc_self_test

X01a1:	mov	a,r2
	add	a,#94h
	jc	X0193
	add	a,#30h
	jnc	X0193
	mov	r1,a
	call	X0226
	mov	a,r1
	jmp	X0430


gotoxy_column:
	mov	r0,#3bh
	mov	a,@r0
	dec	a
	cpl	a
	add	a,r2
	cpl	a
	inc	a
	mov	r0,#31h
	mov	@r0,a

	sel	rb0
	mov	a,r4
	jnc	X01c1

	anl	a,#0fdh		; clear GOTOXY column flag
X01c1:	orl	a,#4		; set GOTOXY row flag
	mov	r4,a
	sel	rb1

	ret


gotoxy_row:
	sel	rb0
	anl	a,#0f8h		; clear ESC sequence, GOTOXY column, and GOTOXY row flags
	xch	a,r4
	sel	rb1

	jb1	X01ce
X01cd:	ret

X01ce:	mov	r0,#3dh
	mov	a,@r0
	cpl	a
	add	a,r2
	jc	X01cd
	call	X0226
	mov	r0,#2fh
	mov	a,@r0
	add	a,r2
	inc	r0
	mov	@r0,a
	inc	r0
	mov	a,@r0
	mov	r0,#3ch
	mov	@r0,a
	jmp	X025a


; write value in A to CRTC control register # in r0
write_crtc_control_reg:
	mov	r4,a		; save data value

	mov	a,#0d0h		; select CRTC
	outl	p2,a

	clr	a		; select CRTC hardware address 0 (address reg)
	xch	a,r0		; write CRTC address register
	movx	@r0,a

	inc	r0		; advance to next CRTC hardware address (control reg)

	xch	a,r4		; get back data value and write CRTC control register
	movx	@r0,a

	xch	a,r4
	mov	r0,a
	mov	a,r4
	orl	p2,#0f0h	; deselect CRTC (and HP-IL, RAM)

	ret


	org	200h

X0200:	mov	r4,a
	mov	r0,#36h
	mov	a,@r0
	xrl	a,#6fh
	jz	X020d
	mov	a,@r0
	inc	@r0
	mov	r0,a
	mov	a,r4
	mov	@r0,a
X020d:	ret


X020e:	mov	r0,#36h

	dis	i
	mov	a,@r0
	inc	r0
	xrl	a,@r0
	jz	X021e
	en	i

	mov	a,@r0
	inc	@r0
	mov	r0,a
	mov	a,@r0
	mov	r4,a
	clr	a
	ret

X021e:	mov	@r0,#60h
	dec	r0
	mov	@r0,#60h
	en	i

	mov	a,r0
	ret


X0226:	call	X022b
	jnz	X0226
	ret


X022b:	mov	r0,#34h
	jmp	X0231

X022f:	mov	r0,#36h
X0231:	mov	a,@r0
	inc	r0
	xrl	a,@r0
	ret


X0235:	mov	r0,#36h
	mov	@r0,#60h
	inc	r0
	mov	@r0,#60h
	ret


X023d:	rl	a
	add	a,#47h
	mov	r1,a
	in	a,p1
	jb1	X024e
	mov	a,r1
	dec	a
X0246:	movp3	a,@a
	clr	c
	rrc	a
	xch	a,r1
	movp3	a,@a
	rrc	a
	jmp	X0253

X024e:	mov	a,r1
	dec	a
	movp3	a,@a
	xch	a,r1
	movp3	a,@a
X0253:	mov	r0,#39h
	add	a,@r0
	xch	a,r1
	dec	r0
	addc	a,@r0
	ret


X025a:	mov	r0,#30h
	mov	a,@r0
	call	X023d
	mov	r4,a
	mov	r0,#3bh
	mov	a,@r0
	cpl	a
	inc	r0
	add	a,@r0
	cpl	a
	add	a,r1
	mov	r1,a
	mov	r0,#33h
	mov	@r0,a
	jnc	X026f
	inc	r4
X026f:	mov	a,r4
	dec	r0
	mov	@r0,a

	mov	r0,#0eh			; write CRTC cursor high reg from a
	call	write_crtc_control_reg

	inc	r0			; write CRTC cursor low reg from r1
	mov	a,r1
	jmp	write_crtc_control_reg


; clear entire display RAM, then enable display
clear_display:
	mov	r1,#10h			; iterate 16 times to clear 4K bytes

	anl	p1,#0feh		; blank display
X027e:	mov	a,r1
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R1
	outl	p2,a

	mov	r0,#0			; clear 256 bytes
	mov	a,#20h
X0286:	movx	@r0,a
	djnz	r0,X0286

	djnz	r1,X027e

	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)

	mov	r1,#4			; clear 4 CRTC control regs
	mov	r0,#0ch			; starting with cursor position high
	clr	a
X0292:	call	write_crtc_control_reg
	inc	r0
	djnz	r1,X0292
	orl	p1,#1			; show display
	ret


X029a:	call	X023d
	xch	a,r1
	mov	r0,#3bh
	add	a,@r0
	jnc	X02a3
	inc	r1
X02a3:	xch	a,r1
	mov	r0,a
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R1
	outl	p2,a
	movx	a,@r1
	orl	p2,#0f0h		; deselect display RAM (and HP-IL, CRTC)
	ret


; ESC Y - set monitor mode
esc_set_monitor_mode:
	sel	rb0
	mov	a,r4
	orl	a,#20h
	mov	r4,a
	sel	rb1
	jmp	esc_replace_mode


; ESC Z - clear monitor mode
esc_clear_monitor_mode:
	sel	rb0
	mov	a,r4
	anl	a,#0dfh
	mov	r4,a
	sel	rb1
	ret


check_monitor_mode:
	sel	rb0
	mov	a,r4
	sel	rb1
	anl	a,#20h
X02c0:	ret


; char is LF
X02c1:	call	X07f9
	jb3	X02c0
	mov	r0,#30h
	mov	a,@r0
	xrl	a,#2fh
	jnz	X02dd
	mov	r0,#39h
	mov	a,@r0
	mov	r1,#3ah
	add	a,@r1
	mov	@r0,a
	jnc	X02ea
	dec	r0
	mov	a,@r0
	inc	a
	anl	a,#0fh
	mov	@r0,a
	jmp	X02ea

X02dd:	dec	r0
	mov	a,@r0
	mov	r1,#3dh
	add	a,@r1
	cpl	a
	inc	r0
	inc	@r0
	add	a,@r0
	jb7	X02fa
	dec	r0
	inc	@r0
X02ea:	call	X07cc
	mov	r0,#30h
	mov	a,@r0
	dec	a
	mov	r4,#20h
	call	X029a
	mov	a,r1
	xch	a,r0
	call	X07f0
	call	X03aa
X02fa:	jmp	X025a

	org	300h

	db	"MC00701A", char_cr, char_lf

; copied to registers 02eh..03dh
X030a:	db	0
	db	0
	db	0
	db	0
	db	0
	db	0
	db	80
	db	80
	db	96
	db	96
	db	0
	db	0
	db	82
	db	80
	db	80
	db	23

; copied to reg 03ah..03dh
X031a:	db	41
	db	40
	db	40
	db	19

; 031e:
crtc_init_tbl_pal_40:
	db	62	; horiz total           # chars
	db	41	; horiz displayed       # chars
	db	49	; horiz sync pos        # chars
	db	035h	; vsync width (high 4)  # scan lines
			; hsync width           # char times
	db	30	; vert total - 1        # char rows     31 * 10 = 310
	db	4	; vert total adj        # scan lines                 + 4 = 314
	db	20	; vert displayed        # char rows
	db	25	; vert sync position    # char rows
	db	030h	; mode
	db	9	; scan lines - 1 / char	# scan lines

; 0328:
crtc_init_tbl_ntsc_40:
	db	62	; horiz total           # chars
	db	41	; horiz displayed       # chars
	db	49	; horiz sync pos        # chars
	db	035h	; vsync width (high 4)  # scan lines
			; hsync width           # char times
	db	28	; vert total - 1        # char rows     29 * 9 = 261
	db	1	; vert total adj        # scan lines                 + 1 = 262
	db	20	; vert displayed        # char rows
	db	23	; vert sync position    # char rows
	db	030h	; mode
	db	8	; scan lines - 1 / char	# scan lines

; 0332:
; crtc_init_tbl_pal_80:
	db	126	; horiz total           # chars
	db	82	; horiz displayed       # chars
	db	96	; horiz sync pos        # chars
	db	03ah	; vsync width (high 4)  # scan lines
			; hsync width           # char times
	db	30	; vert total - 1        # char rows     31 * 10 = 310
	db	2	; vert total adj        # scan lines                 + 2 = 312
	db	24	; vert displayed        # char rows
	db	27	; vert sync position    # char rows
	db	030h	; mode
	db	9	; scan lines - 1 / char	# scan lines

; 033ch:
crtc_init_tbl_ntsc_80:
	db	125	; horiz total           # chars
	db	82	; horiz displayed       # chars
	db	96	; horiz sync pos        # chars
	db	03ah	; vsync width (high 4)  # scan lines
			; hsync width           # char times
	db	28	; vert total - 1        # char rows     29 * 9 = 261
	db	1	; vert total adj        # scan lines                 + 1 = 262
	db	24	; vert displayed        # char rows
	db	25	; vert sync position    # char rows
	db	030h	; mode
	db	8	; scan lines - 1 / char	# scan lines
	
; 0346
; table of fifty multiples of 82, for line starts in display RAM
	db	000h,000h
	db	000h,052h
	db	000h,0a4h
	db	000h,0f6h
	db	001h,048h
	db	001h,09ah
	db	001h,0ech
	db	002h,03eh
	db	002h,090h
	db	002h,0e2h
	db	003h,034h
	db	003h,086h
	db	003h,0d8h
	db	004h,02ah
	db	004h,07ch
	db	004h,0ceh
	db	005h,020h
	db	005h,072h
	db	005h,0c4h
	db	006h,016h
	db	006h,068h
	db	006h,0bah
	db	007h,00ch
	db	007h,05eh
	db	007h,0b0h
	db	008h,002h
	db	008h,054h
	db	008h,0a6h
	db	008h,0f8h
	db	009h,04ah
	db	009h,09ch
	db	009h,0eeh
	db	00ah,040h
	db	00ah,092h
	db	00ah,0e4h
	db	00bh,036h
	db	00bh,088h
	db	00bh,0dah
	db	00ch,02ch
	db	00ch,07eh
	db	00ch,0d0h
	db	00dh,022h
	db	00dh,074h
	db	00dh,0c6h
	db	00eh,018h
	db	00eh,06ah
	db	00eh,0bch
	db	00fh,00eh
	db	00fh,060h
	db	00fh,0b2h

	
X03aa:	mov	r0,#02fh
	mov	a,@r0
	call	X023d
	mov	r0,#0ch
	call	write_crtc_control_reg
	inc	r0
	mov	a,r1
	jmp	write_crtc_control_reg


; ESC z - self test
esc_self_test:
	dis	i
	anl	p1,#0feh		; blank display
	call	X069c
	sel	rb0
	mov	a,r5
	anl	a,#9fh
	mov	r5,a
	sel	rb1
	clr	f1
	sel	mb1
	assume	mb:1
	call	X08a9
	jz	X03ce
	sel	rb0
	mov	a,r5
	orl	a,#20h
	mov	r5,a
	sel	rb1
X03ce:	cpl	f1
	call	X08a9
	sel	mb0
	assume	mb:0
	jz	X03da
	sel	rb0
	mov	a,r5
	orl	a,#40h
	mov	r5,a
	sel	rb1
X03da:	call	X06a4
	jmp	esc_soft_reset


	org	400h

	db	esc_disable_cursor & 0ffh		; ESC < - disable cursor display
	db	esc_set_pal & 0ffh			; ESC = - select PAL mode
	db	esc_enable_cursor & 0ffh		; ESC > - enable cursor display
	db	000h
	db	000h
	db	x_esc_cursor_up & 0ffh			; ESC A - cursor up
	db	x_esc_cursor_down & 0ffh		; ESC B - cursor down	
	db	x_esc_cursor_right & 0ffh		; ESC C - cursor right
	db	x_esc_cursor_left & 0ffh		; ESC D - cursor left
	db	esc_soft_reset & 0ffh			; ESC E - soft reset
	db	000h
	db	000h
	db	esc_home_cursor_current_page & 0ffh	; ESC H - home cursor current page
	db	000h
	db	x_esc_clear_to_end_of_page & 0ffh	; ESC J - clear to end of page
	db	x_esc_clear_to_end_of_line & 0ffh	; ESC K - clear to end of line
	db	x_esc_insert_line & 0ffh		; ESC L - insert line
	db	x_esc_delete_line & 0ffh		; ESC M - delete line
	db	x_esc_insert_mode & 0ffh		; ESC N - select insert mode
	db	x_esc_delete_character & 0ffh		; ESC O - delete character
	db	000h
	db	esc_select_insert_cursor & 0ffh		; ESC Q - select insert cursor (but not insert mode)
	db	x_esc_replace_mode & 0ffh		; ESC R - set replace mode
	db	esc_scroll_up & 0ffh			; ESC S - scroll up (move window down)
	db	esc_scroll_down & 0ffh			; ESC T - scroll down (move window up)
	db	000h
	db	000h
	db	000h
	db	000h
	db	x_esc_set_monitor_mode & 0ffh		; ESC Y - set monitor mode
	db	x_esc_clear_monitor_mode & 0ffh		; ESC Z - disable monitor mode
	db	esc_set_80_col & 0ffh			; ESC [ - set 80 col
	db	esc_set_ntsc & 0ffh			; ESC \ - select NTSC mode (manual has forward slash)
	db	esc_set_40_col & 0ffh			; ESC ] - set 40 col
	db	000h
	db	000h
	db	000h
	db	000h
	db	000h
	db	000h
	db	000h
	db	esc_hard_reset & 0ffh			; ESC e - hard reset
	db	000h
	db	000h
	db	esc_home_cursor_display_memory & 0ffh	; ESC h - home cursor display memory
	db	000h
	db	esc_select_char_set_roman_8 & 0ffh	; ESC j
	db	esc_select_char_set_ascii_inv & 0ffh	; ESC k


X0430:	movp	a,@a		; look up esc char in table
	jz	X0435		; if entry is zero, no effect
	mov	a,r1
	jmpp	@a

X0435:	ret


; ESC A - cursor up
x_esc_cursor_up:
	jmp	esc_cursor_up

; ESC B - cursor down
x_esc_cursor_down:
	jmp	esc_cursor_down

; ESC C - cursor right
x_esc_cursor_right:
	jmp	esc_cursor_right

; ESC D - cursor left
x_esc_cursor_left:
	jmp	esc_cursor_left

; ESC J - clear to end of page
x_esc_clear_to_end_of_page:
	jmp	esc_clear_to_end_of_page

; ESC K - clear to end of line
x_esc_clear_to_end_of_line:
	jmp	esc_clear_to_end_of_line

; ESC L - insert line
x_esc_insert_line:
	jmp	esc_insert_line

; ESC M - delete line
x_esc_delete_line:
	jmp	esc_delete_line

; ESC N - insert mode
x_esc_insert_mode:
	jmp	esc_insert_mode

; ESC O - delete character
x_esc_delete_character:
	sel	mb1
	assume	mb:1
	jmp	esc_delete_character
	assume	mb:0

; ESC R - replace mode
x_esc_replace_mode:
	jmp	esc_replace_mode

; ESC Y - set monitor mode
x_esc_set_monitor_mode:
	jmp	esc_set_monitor_mode

; ESC Z - clear monitor mode
x_esc_clear_monitor_mode:
	jmp	esc_clear_monitor_mode


; ESC > - enable cursor
esc_enable_cursor:
	mov	r1,#60h
	sel	rb0
	mov	a,r5
	anl	a,#0f7h
	jmp	X045f

; ESC < - disable cursor
esc_disable_cursor:
	mov	r1,#20h
	sel	rb0
	mov	a,r5
	orl	a,#8
X045f:	mov	r5,a
	sel	rb1
	mov	a,r1
	mov	r0,#0ah
	jmp	write_crtc_control_reg


; ESC e - hard reset
esc_hard_reset:
	jmp	display_init


; ESC E - soft reset
esc_soft_reset:
	call	esc_replace_mode

	in	a,p1
	jb1	X046f
	jmp	esc_set_40_col

X046f:	jmp	esc_set_80_col


; ESC h: home cursor display memory
esc_home_cursor_display_memory:
	mov	r0,#2fh
	clr	a
	mov	@r0,a
	call	X03aa

; ESC H: home cursor_current_page
esc_home_cursor_current_page:
	mov	r0,#2fh
	mov	a,@r0
	inc	r0
	mov	@r0,a
	mov	r0,#3bh
	mov	a,@r0
	inc	r0
	mov	@r0,a
	jmp	X025a


; ESC Q: select insert cursor (but not insert mode)
esc_select_insert_cursor:
	anl	p1,#0f7h	; clear cursor char select
X0485:	ret


; ESC S - scroll up (move window down)
esc_scroll_up:
	mov	r0,#3dh
	mov	a,@r0
	mov	r0,#2fh
	add	a,@r0
	add	a,#0d1h
	jc	X0485
	inc	@r0
	inc	r0
	inc	@r0

X0493:	call	X03aa
	jmp	X025a


; ESC T - scroll down (move window up)
esc_scroll_down:
	mov	r0,#2fh
	mov	a,@r0
	jz	X0485
	dec	a
	mov	@r0,a
	inc	r0
	mov	a,@r0
	dec	a
	mov	@r0,a
	jmp	X0493


; ESC [ - set 80 column
esc_set_80_col:
	anl	p1,#0feh		; blank display
	orl	p1,#2			; set hardware 80 col
	sel	rb0
	mov	r3,#32h
	mov	a,r5
	anl	a,#0feh
	jmp	X04b8


; ESC ] - set 40 column
esc_set_40_col:
	anl	p1,#0fch		; blank display and set hardware 80 col
	sel	rb0
	mov	r3,#1eh
	mov	a,r5
	orl	a,#1
X04b8:	mov	r5,a
	jb2	X04d8
	mov	a,#0ah
	jmp	X04d6


; ESC \ - set NTSC mode
esc_set_ntsc:
	anl	p1,#0feh		; blank display
	sel	rb0
	mov	r3,#28h
	mov	a,r5
	anl	a,#0fbh
	jmp	X04d1

; ESC = - select PAL mode
esc_set_pal:
	anl	p1,#0feh		; blank display
	sel	rb0
	mov	r3,#1eh
	mov	a,r5
	orl	a,#4
X04d1:	mov	r5,a
	jb0	X04d8
	mov	a,#14h
X04d6:	add	a,r3
	mov	r3,a
X04d8:	mov	a,r3
	sel	rb1
	mov	r1,a
	in	a,p1
	jb1	X04e8
	call	X0054

; copy 4 bytes from table at 031a to registers 03ah..03dh
	mov	r0,#3ah
	mov	r1,#1ah
	mov	r5,#4
	jmp	X0068

X04e8:	jmp	X0054



; ESC k: select ASCII/inverse character set
esc_select_char_set_ascii_inv:
	orl	p1,#4		; set hardware char set select
	sel	rb0		; update status
	mov	a,r5
	anl	a,#0fdh
	jmp	X04f8

; ESC j: select Roman-8 character set
esc_select_char_set_roman_8:
	anl	p1,#0fbh	; clear hardware char set select
	sel	rb0		; update status
	mov	a,r5
	orl	a,#2

X04f8:	mov	r5,a
	sel	rb1
	ret


	org	500h

; ESC A - cursor up
esc_cursor_up:
	mov	r0,#2fh
	mov	a,@r0
	inc	r0
	xrl	a,@r0
	jz	X0535
	mov	a,@r0
X0508:	dec	a
	mov	@r0,a
	jmp	X025a


; ESC B - cursor down
esc_cursor_down:
	mov	r0,#2fh
	mov	a,@r0
	mov	r1,#3dh
	add	a,@r1
	inc	r0
	xrl	a,@r0
	jz	X0535
	inc	@r0
	jmp	X025a


; ESC J - clear to end of page
esc_clear_to_end_of_page:
	call	X07a1
	mov	r0,#30h
	mov	a,@r0
	mov	r0,#42h
	mov	@r0,a
X0521:	mov	r0,#2fh
	mov	a,@r0
	mov	r1,#3dh
	add	a,@r1
	inc	a
	inc	r0
	inc	@r0
	xrl	a,@r0
	jz	X0531
	call	X07cc
	jmp	X0521

X0531:	mov	r1,#42h
	mov	a,@r1
	mov	@r0,a
X0535:	ret


; insert character
X0536:	dis	i
	call	X069c
	mov	a,r2
	mov	r6,a
	mov	r0,#32h
	mov	a,@r0
	mov	r4,a
	inc	r0
	mov	a,@r0
	mov	r1,a
	mov	r0,#3ch
	mov	a,@r0
	mov	r7,a
	mov	r0,#30h
	mov	a,@r0
	mov	r5,a
X054a:	call	clear_vert_int_wait_clear
	call	X05e2
	jz	X05d7
	mov	r0,#30h
	mov	a,@r0
	xrl	a,r5
	jnz	X055c
	mov	r0,#3ch
	mov	a,@r0
	dec	a
	jz	X0561
X055c:	mov	a,r6
	xrl	a,#20h
	jz	X05b4
X0561:	mov	r0,#45h
	mov	a,r6
	mov	@r0,a
	call	X06a4
	mov	r1,#42h
	mov	r0,#3ch
	mov	a,@r0
	mov	@r1,a
	inc	r1
	mov	r0,#2fh
	mov	a,@r0
	mov	@r1,a
	inc	r1
	inc	r0
	mov	a,@r0
	mov	@r1,a
	mov	a,r5
	xrl	a,#2fh
	jnz	X058a
	call	X0167
	call	X02c1
	mov	r0,#43h
	mov	a,@r0
	dec	a
	mov	@r0,a
	inc	r0
	mov	a,@r0
	dec	a
	mov	@r0,a
	jmp	X058f

X058a:	mov	a,r5
	inc	a
	mov	@r0,a
	call	esc_insert_line
X058f:	mov	r0,#45h
	mov	a,@r0
	mov	r4,a
	mov	r1,#33h
	mov	a,@r1
	mov	r0,a
	dec	r1
	mov	a,@r1
	call	X07f0
	mov	r0,#30h
	mov	a,@r0
	dec	a
	mov	r4,#0
	call	X00c4
	mov	r1,#42h
	mov	r0,#3ch
	mov	a,@r1
	mov	@r0,a
	inc	r1
	mov	r0,#2fh
	mov	a,@r1
	mov	@r0,a
	inc	r1
	inc	r0
	mov	a,@r1
	mov	@r0,a
	call	X069c
X05b4:	mov	r0,#3ch
	mov	a,@r0
	dec	a
	mov	@r0,a
	jnz	X05cd
	dec	r0
	mov	a,@r0
	inc	r0
	mov	@r0,a
X05bf:	mov	r0,#2fh
	mov	a,@r0
	mov	r1,#3dh
	add	a,@r1
	inc	a
	inc	r0
	inc	@r0
	xrl	a,@r0
	jnz	X05cd
	dec	r0
	inc	@r0
X05cd:	call	X03aa
	call	X025a
	call	X06a4
	call	clear_vert_int
	en	i
	ret


X05d7:	inc	r5
	mov	a,r5
	call	X023d
	mov	r4,a
	mov	r0,#3bh
	mov	a,@r0
	mov	r7,a
	jmp	X054a

X05e2:	mov	a,r4
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R4
	outl	p2,a
	movx	a,@r1
	xch	a,r6
	movx	@r1,a
	inc	r1
	mov	a,r1
	jnz	X05ee
	inc	r4
X05ee:	djnz	r7,X05e2
	movx	a,@r1
	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)
	ret


	org	600h

; ESC M - delete line
esc_delete_line:
	dis	i
	call	wait_vert_int_and_clear
	call	X069c
	anl	p1,#0feh	; clear display blank
	mov	r0,#30h
	mov	a,@r0
	mov	r5,a
	mov	r7,a
	mov	r6,#1
X060e:	mov	a,r5
	call	X029a
	jnz	X0617
	inc	r5
	inc	r6
	jmp	X060e

X0617:	call	X06b9
	mov	r0,#3fh
	mov	a,r6
	mov	@r0,a
	dec	r0
	mov	a,#0cfh
	add	a,r6
	add	a,r7
	cpl	a
	mov	@r0,a
	mov	a,r6
	add	a,r7
	call	X023d
	mov	r4,a
	mov	a,r1
	mov	r6,a
	mov	a,r7
	call	X023d
	mov	r5,a
X062f:	mov	r0,#3eh
	mov	a,@r0
	jz	X063a
	dec	a
	mov	@r0,a
	call	X06d9
	jmp	X062f

X063a:	mov	r7,#30h
	mov	r0,#3fh
	mov	a,@r0
	mov	r6,a
X0640:	mov	r0,#3ah
	mov	a,@r0
	mov	r5,a
	dec	r7
	mov	a,r7
	call	X023d
	mov	r0,a
	call	X07dc
	djnz	r6,X0640
	call	X06a4
	call	clear_vert_int_wait_clear
	orl	p1,#1		; show display
	en	i
	ret


; ESC L - insert line
esc_insert_line:
	dis	i
	call	wait_vert_int_and_clear
	anl	p1,#0feh	; clear display blank
	call	X069c
	mov	r0,#30h
	mov	a,@r0
	mov	r7,a
	call	X06b9
	mov	r0,#3eh
	mov	@r0,#30h
X0666:	mov	a,@r0
	mov	r7,a
	dec	a
	mov	@r0,a
	call	X023d
	mov	r4,a
	mov	a,r1
	mov	r6,a
	mov	a,r7
	call	X023d
	mov	r5,a
	call	X06d9
	mov	r1,#30h
	mov	a,@r1
	mov	r0,#3eh
	xrl	a,@r0
	jnz	X0666
	mov	r0,#3ah
	mov	a,@r0
	mov	r5,a
	mov	a,@r1
	call	X023d
	call	X07dc
	mov	a,#2fh
	call	X00c2
	call	X06a4
	call	clear_vert_int_wait_clear
	orl	p1,#1		; show display
	en	i

	sel	rb0		; XXX set line inserted flag?
	mov	a,r4
	orl	a,#10h
	xch	a,r4
	sel	rb1
	jb4	X069a		; XXX test prev value of line inserted flag?
	ret

X069a:	jmp	X0722

X069c:	mov	r0,#40h
	mov	a,r6
	mov	@r0,a
	inc	r0
	mov	a,r7
	mov	@r0,a
	ret

X06a4:	mov	r0,#40h
	mov	a,@r0
	mov	r6,a
	inc	r0
	mov	a,@r0
	mov	r7,a
	ret


clear_vert_int_wait_clear:
	anl	p2,#70h			; pulse vertical interrupt acknowlege
	orl	p2,#0f0h

wait_vert_int_and_clear:
	jni	clear_vert_int		; wait for vertical interrupt
	jmp	wait_vert_int_and_clear

clear_vert_int:
	anl	p2,#70h		; pulse vertical interrupt acknowledge
	orl	p2,#0f0h
	ret


X06b9:	mov	a,r7
	dec	a
	mov	r5,a
X06bc:	mov	a,r5
	jb7	X06c7
	call	X029a
	jnz	X06c7
	dec	r5
	inc	r6
	jmp	X06bc

X06c7:	inc	r5
	mov	r0,#30h
	mov	a,r5
	mov	@r0,a
	mov	r7,a
	dec	r0
	cpl	a
	add	a,@r0
	jb7	X06d4
	mov	a,r7
	mov	@r0,a
X06d4:	call	X03aa
	call	X0167
	ret

X06d9:	mov	r0,#3ah
	mov	a,@r0
	mov	r7,a
	mov	a,r6
	mov	r0,a
X06df:	mov	a,r4
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R4
	outl	p2,a
	movx	a,@r0
	mov	r6,a
	inc	r0
	mov	a,r0
	jnz	X06ea
	inc	r4
X06ea:	mov	a,r5
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R5
	outl	p2,a
	mov	a,r6
	movx	@r1,a
	inc	r1
	mov	a,r1
	jnz	X06f5
	inc	r5
X06f5:	djnz	r7,X06df
	mov	a,r0
	mov	r6,a
	ret


	org	700h

vert_intr_handler:
	sel	rb0		; save A
	mov	r2,a

	sel	rb1
X0703:	mov	a,r0
	mov	r0,#7ah
	mov	@r0,a
	inc	r0
	mov	a,r1
	mov	@r0,a
	inc	r0
X070b:	mov	a,r4
	mov	@r0,a
	inc	r0
	mov	a,r5
	mov	@r0,a
	inc	r0
	in	a,p2
	mov	@r0,a
	orl	p2,#0f0h
	call	X022b
	jz	X074f
	call	X07f9
	cpl	a
	jb3	X072a
	jb4	X0722
	jmp	esc_insert_line

X0722:	mov	r0,#30h
	mov	a,@r0
	dec	a
	mov	r4,#0
	call	X00c4
X072a:	call	X022b
	jz	X074f
	mov	a,@r0
	inc	@r0
	mov	r0,a
	mov	a,@r0
	mov	r4,a
	mov	r1,#33h
	mov	a,@r1
	mov	r0,a
	dec	r1
	mov	a,@r1
	call	X07f0
	mov	a,#33h
	xch	a,r0
	inc	a
	mov	@r0,a
	jnz	X0746
	inc	r1
	mov	a,r1
	dec	r0
	mov	@r0,a
X0746:	mov	r1,#3ch
	mov	a,@r1
	dec	a
	jz	X0778
	mov	@r1,a
	jmp	X072a

X074f:	mov	@r0,#50h
	dec	r0
	mov	@r0,#50h
	clr	f1
	mov	r1,#32h
	mov	r0,#0eh
	mov	a,@r1
	call	write_crtc_control_reg
	inc	r0
	inc	r1
	mov	a,@r1
	call	write_crtc_control_reg

X0761:	anl	p2,#70h		; pulse vertical int ack
	orl	p2,#0f0h

	mov	r0,#7eh
	mov	a,@r0
	outl	p2,a
	dec	r0
	mov	a,@r0
	mov	r5,a
	dec	r0
	mov	a,@r0
	mov	r4,a
	dec	r0
	mov	a,@r0
	mov	r1,a
	dec	r0
	mov	a,@r0
	mov	r0,a

	sel	rb0		; restore A and return from interrupt
	mov	a,r2
	retr

X0778:	sel	rb0
	mov	a,r4
	sel	rb1
	cpl	a
	jb4	X0792
	mov	r0,#30h
	mov	a,@r0
	xrl	a,#2fh
	jz	X0792
	dec	r0
	mov	a,@r0
	mov	r1,#3dh
	add	a,@r1
	inc	r0
	xrl	a,@r0
	jnz	X0792
	dec	r0
	inc	@r0
	call	X03aa
X0792:	call	X0167
	call	X02c1
	sel	rb0
	mov	a,r4
	orl	a,#8
	mov	r4,a
	sel	rb1
	jmp	X0761


; ESC K - clear to end of line
esc_clear_to_end_of_line:
	clr	f0
	jmp	X07a3

X07a1:	clr	f0
	cpl	f0

X07a3:	dis	i
	mov	r0,#3ch
	mov	a,@r0
	mov	r5,a
	mov	r0,#33h
	mov	a,@r0
	mov	r1,a
	dec	r0
	mov	a,@r0
	call	clear_vert_int_wait_clear
	call	X07dc
	mov	r0,#30h
	mov	a,@r0
	mov	r5,a
	jf0	X07bc
	call	X029a
	jz	X07c1
X07bc:	mov	a,r5
	call	X00c2
	en	i
	ret


X07c1:	mov	a,r5
	call	X00c2
	mov	a,r5
	inc	a
	mov	r0,#3eh
	mov	@r0,a
	sel	mb1
	assume	mb:1
	jmp	X0bd4
	assume	mb:0


X07cc:	dis	i
	call	clear_vert_int_wait_clear
	mov	r1,#3ah
	mov	a,@r1
	mov	r5,a
	mov	r0,#30h
	mov	a,@r0
	call	X023d
	call	X07dc
	en	i
	ret


X07dc:	mov	r4,#20h
	mov	r0,a
	dec	r0
X07e0:	inc	r0
	mov	a,r0
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R0
	outl	p2,a
X07e5:	jz	X07e0
	mov	a,r4
	movx	@r1,a
	inc	r1
	mov	a,r1
	djnz	r5,X07e5
	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)
	ret


X07f0:	mov	r1,a
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R1
	outl	p2,a
	mov	a,r4
	movx	@r0,a
	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)
	ret


X07f9:	sel	rb0
	mov	a,r4
	anl	a,#0f7h
	xch	a,r4
	sel	rb1
	ret


	org	0800h
	assume	mb:1

hpil_set_unaddressed:
	mov	r0,#4			; set no HP-IL address assigned (31)
	mov	a,#31
	call	hpil_write_reg

	sel	rb0
	mov	r6,#31
	sel	rb1
	ret


; HP-IL R (Receiver) state machine
; For HP-IL chip (1LB3), use state machine specification in HP-IL
; Integrated Circuit User's Manual, figure 3-2, rather than that of
; HP-IL Interface Specification, figure 2-3.

hpil_sm_20:
	mov	r1,#hpil_sm_20_state
	mov	a,@r1
	jb0	hpil_sm_20_01
	jb1	hpil_sm_20_02
	jb2	hpil_sm_20_04
	jb3	hpil_sm_20_08
; if invalid state, falls into hpil_sm_20_goto_01

hpil_sm_20_goto_01:
	mov	a,r6
	anl	a,#7fh
	mov	r6,a
	mov	@r1,#hpil_sm_20_state_01
	
hpil_sm_20_01:
	sel	rb0
	mov	a,r5
	sel	rb1
	anl	a,#80h
	jz	X0828

	mov	a,r7		; check saved state of HP-IL interrupt register
	anl	a,#16h		; any of IFCR, FRAV, FRNS set?
	jnz	X0829		;   yes
X0828:	ret			;   no, done

X0829:	mov	a,r7
	mov	r3,a
	anl	a,#10h		; IFCR?
	jz	X0839		;   no

	mov	r2,#90h
	mov	a,r3
	anl	a,#1fh
	orl	a,#80h
	mov	r3,a
	jmp	hpil_sm_20_goto_02

X0839:	mov	r0,#2		; read HP-IL data reg into r2
	call	hpil_read_reg
	mov	r2,a

hpil_sm_20_goto_02:
	mov	@r1,#hpil_sm_20_state_02
	call	X0e33

hpil_sm_20_02:
	sel	rb0
	mov	a,r5
	sel	rb1
	anl	a,#80h
	jnz	X0885

	call	X0ee1
	jnz	hpil_sm_20_goto_goto_04
	call	hpil_check_msg_non_data_and_frns
	jz	X0858
	mov	r0,#27h
	mov	a,@r0
	anl	a,#2
	jnz	hpil_sm_20_goto_goto_04
X0858:	call	hpil_check_msg_non_data_and_frav
	jz	X0860
	call	X0db6
	jz	hpil_sm_20_goto_goto_04
X0860:	call	X0db6
	jz	X086b

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0feh
	jz	hpil_sm_20_goto_goto_04

X086b:	call	X0e51
	jnz	hpil_sm_20_goto_01
	call	hpil_check_msg_non_data_and_frns
	jz	X087a

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0fch
	jnz	hpil_sm_20_goto_01

X087a:	call	X0db6
	jz	X0885

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0feh
	jnz	hpil_sm_20_goto_01

X0885:	ret

hpil_sm_20_goto_goto_04:
	mov	@r1,#hpil_sm_20_state_04
	mov	a,r6
	anl	a,#7fh
	mov	r6,a

hpil_sm_20_04:
	call	X0dc6
	jnz	X0829
	mov	r0,#hpil_sm_d_state
	mov	a,@r0
	anl	a,#hpil_sm_d_state_02
	jnz	X089e
	sel	rb0
	mov	a,r5
	sel	rb1
	anl	a,#80h
	jnz	hpil_sm_20_goto_08
X089e:	ret

hpil_sm_20_goto_08:
	mov	@r1,#hpil_sm_20_state_08

hpil_sm_20_08:
	mov	r0,#hpil_sm_d_state
	mov	a,@r0
	anl	a,#hpil_sm_d_state_02
	jnz	hpil_sm_20_goto_01
	ret


X08a9:	mov	r0,#49h
	mov	@r0,#0
	mov	r0,#46h
	mov	@r0,#0
	inc	r0
	mov	@r0,#0
X08b4:	call	X08cc
	jnz	X08cb
	mov	r0,#47h
	mov	a,@r0
	add	a,#8
	jnc	X08c2
	dec	r0
	inc	@r0
	inc	r0
X08c2:	mov	@r0,a
	mov	r0,#49h
	mov	a,@r0
	dec	a
	mov	@r0,a
	jnz	X08b4
	clr	a
X08cb:	ret


X08cc:	call	X08f0
X08ce:	call	X09cc
	call	X09ee
	djnz	r5,X08ce
	mov	r0,#48h
	mov	a,@r0
	dec	a
	mov	@r0,a
	jnz	X08ce
	call	X08f0
X08dd:	call	X09f3
	mov	r0,a
	call	X09cc
	xrl	a,r0
	jnz	X08cb
	djnz	r5,X08dd
	mov	r0,#48h
	mov	a,@r0
	dec	a
	mov	@r0,a
	jnz	X08dd
	clr	a
	ret


X08f0:	mov	r0,#46h
	mov	a,@r0
	mov	r4,a
	inc	r0
	mov	a,@r0
	mov	r1,a
	inc	r0
	mov	@r0,#8
	mov	r5,#0
	jmp	X09e9


	org	900h

hpil_sm_21:
	mov	r1,#hpil_sm_21_state
	mov	a,@r1
	jb0	hpil_sm_21_01
	jb1	hpil_sm_21_02
	jb2	hpil_sm_21_04
	jb3	hpil_sm_21_08

hpil_sm_21_goto_01:
	mov	@r1,#hpil_sm_21_state_01

hpil_sm_21_01:
	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0fch
	jnz	hpil_sm_21_goto_02

	ret

hpil_sm_21_goto_02:
	mov	@r1,#hpil_sm_21_state_02

hpil_sm_21_02:
	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0ffh & ~(hpil_sm_t_state_tids | hpil_sm_t_state_tads)
	jz	hpil_sm_21_goto_01
	call	X0fd7
	jz	X0929
	mov	r0,#hpil_sm_d_state
	mov	a,@r0
	anl	a,#4
	jz	hpil_sm_21_goto_04
X0929:	ret

hpil_sm_21_goto_04:
	mov	@r1,#hpil_sm_21_state_04

hpil_sm_21_04:
	mov	r0,#hpil_sm_d_state
	mov	a,@r0
	anl	a,#4
	jnz	hpil_sm_21_goto_08
	ret

hpil_sm_21_goto_08:
	mov	@r1,#hpil_sm_21_state_08

hpil_sm_21_08:
	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0fch
	jz	hpil_sm_21_goto_01

	call	X0fd7
	jnz	X0956

	mov	a,r7
	anl	a,#1
	jz	X0956

	mov	r0,#hpil_sm_20_state
	mov	a,@r0
	anl	a,#hpil_sm_20_state_01
	jnz	hpil_sm_21_goto_02
	call	hpil_check_msg_non_data
	jz	X0956
	mov	a,r7
	anl	a,#2
	jnz	hpil_sm_21_goto_02
X0956:	ret


; HP-IL D (Driver) state machine
; For HP-IL chip (1LB3), use state machine specification in HP-IL
; Integrated Circuit User's Manual, figure 3-3, rather than that of
; HP-IL Interface Specification, figure 2-4.

hpil_sm_d:
	mov	r1,#hpil_sm_d_state
	mov	a,@r1
	jb0	hpil_sm_d_dids
	jb1	x_hpil_sm_d_02
	jb2	hpil_sm_d_04
	jb3	hpil_sm_d_08

hpil_sm_d_goto_dids:
	mov	@r1,#1

hpil_sm_d_dids:
	mov	a,r7
	anl	a,#1				; ORAV? possible proxy for SDYS+SCHS?
	jz	hpil_sm_d_goto_08

	mov	r0,#hpil_sm_20_state		; test ACRS? RITS?
	mov	a,@r0
	anl	a,#hpil_sm_20_state_08
	jnz	hpil_sm_d_goto_02

	mov	r0,#hpil_sm_21_state		; test ACRS? RITS?
	mov	a,@r0
	anl	a,#hpil_sm_21_state_04
	jnz	X0982
	ret

; retransmit a frame
hpil_sm_d_goto_02:
	mov	r0,#2		; write A to HP-IL data reg, transmitting a
	mov	a,r2		;   frame with the received control bits
	call	hpil_write_reg
	mov	@r1,#2
	ret

x_hpil_sm_d_02:
	jmp	hpil_sm_d_02_04_08


; transmit a frame - write R1 into HP-IL interrupt register (incl. frame control bits),
;                    write data bits from R2 into HP-IL data register
X0982:	mov	r0,#1		; HP-IL interrupt register
	sel	rb0
	mov	a,r1
	sel	rb1
	call	hpil_write_reg

	mov	r0,#2		; HP-IL data register
	sel	rb0
	mov	a,r0
	sel	rb1
	call	hpil_write_reg

	mov	@r1,#4		; next time we write the HP-IL interrupt register, enable FRAV int only
	ret


hpil_sm_d_04:
	jmp	hpil_sm_d_02_04_08

hpil_sm_d_goto_08:
	mov	@r1,#8


hpil_sm_d_08:
	jmp	hpil_sm_d_02_04_08

hpil_sm_d_02_04_08:
	mov	a,r7		; poll ORAV waiting for transmission to complete
	anl	a,#1
	jnz	hpil_sm_d_goto_dids
	ret


; HP-IL L (Listener) state machine 1
; HP-IL Interface Specification, figure 2-9

hpil_sm_lp:
	mov	r1,#hpil_sm_lp_state
	mov	a,@r1
	jb0	hpil_sm_lp_lpis
	jb1	hpil_sm_lp_lpas

hpil_sm_lp_goto_lpis:
	mov	@r1,#hpil_sm_lp_state_lpis
	call	X0ed8

hpil_sm_lp_lpis:
	call	X0eb4
	jz	X09b5
	mov	r0,#hpil_sm_aa_state
	mov	a,@r0
	anl	a,#hpil_sm_aa_state_aecs
	jnz	hpil_ms_lp_goto_lpas
X09b5:	ret

hpil_ms_lp_goto_lpas:
	mov	@r1,#hpil_sm_lp_state_lpas
	call	hpil_set_listener_active_if_not_talker

hpil_sm_lp_lpas:
	call	hpil_check_msg_non_data
	jz	X09cb
	mov	a,r6
	anl	a,#8
	jnz	X09cb
	call	X0d4a
	jnz	X09cb
	call	X0eb4
	jz	hpil_sm_lp_goto_lpis
X09cb:	ret


X09cc:	mov	a,r7
	clr	c
	rlc	a
	mov	r7,a
	jnc	X09e6
	jf0	X09d6
	jmp	X09dd

X09d6:	clr	f0
	mov	r6,#1
	mov	r7,#1
	jmp	X09e6

X09dd:	mov	a,r6
	clr	c
	rlc	a
	mov	r6,a
	mov	r7,#1
	jnc	X09e6
	cpl	f0
X09e6:	mov	a,r7
	orl	a,r6
	ret

X09e9:	clr	f0
	cpl	f0
	mov	r7,#80h
	ret

X09ee:	call	X0fe3
	movx	@r1,a
	jmp	X09f7

X09f3:	call	X0fe3
	movx	a,@r1
	mov	r0,a
X09f7:	inc	r1
	mov	a,r1
	jnz	X09fc
	inc	r4
X09fc:	mov	a,r0
	ret


	org	0a00h

; HP-IL AA (Auto Address) state machine, capability AA1,2
; HP-IL Interface Specification, figure 2-12

hpil_sm_aa:
	mov	r1,#25h
	mov	a,@r1
	jb0	hpil_sm_aa_aaus
	jb1	hpil_sm_aa_aais
	jb2	hpil_sm_aa_aacs
	jb3	hpil_sm_aa_asis
	jb4	hpil_sm_aa_awps
	jb5	hpil_sm_aa_aecs

hpil_sm_aa_goto_aaus:
	sel	rb0			; set no HP-IL address assigned (31) - same as calling hpil_set_unaddressed
	mov	r6,#1fh
	sel	rb1

	mov	a,#1fh			; set loop address register to unaddressed
	mov	r0,#4
	call	hpil_write_reg
	mov	@r1,#1
	ret

hpil_sm_aa_aaus:
	call	X0e77
	jnz	hpil_sm_aa_goto_aaus
	call	X0ea1
	jz	X0a32
	mov	a,r2
	anl	a,#0e0h		; mask off address bits from ready message
	xrl	a,#hpil_rdy_aad
	jz	X0a33
	mov	a,r2
	anl	a,#0e0h
	xrl	a,#hpil_rdy_aes
	jz	X0a5d
X0a32:	ret

; AAUS and AAD received
X0a33:	mov	a,r2
	anl	a,#1fh
	sel	rb0
	mov	r7,a
	sel	rb1
	inc	r2
	mov	@r1,#hpil_sm_aa_state_aais

hpil_sm_aa_aais:
	call	X0e77
	jnz	hpil_sm_aa_goto_aaus
	mov	a,r2
	anl	a,#0e0h		; mask off address bits from ready message
	xrl	a,#hpil_rdy_aad	; looking for naa
	jnz	X0a4e

	mov	r0,#22h
	mov	a,@r0
	anl	a,#2
	jnz	X0a4f
X0a4e:	ret

X0a4f:	sel	rb0		; write loop addrss register from R7 (doesn't update R6???)
	mov	a,r7
	sel	rb1
	mov	r0,#4
	call	hpil_write_reg

	mov	@r1,#hpil_sm_aa_state_aacs

hpil_sm_aa_aacs:
	call	X0e77
	jnz	hpil_sm_aa_goto_aaus
	ret

; AAUS and AES received
X0a5d:	mov	a,r2
	anl	a,#1fh
	sel	rb0
	mov	r7,a
	sel	rb1
	inc	r2
	mov	@r1,#hpil_sm_aa_state_asis

hpil_sm_aa_asis:
	call	X0e77
	jnz	hpil_sm_aa_goto_aaus
	mov	a,r2
	anl	a,#0e0h		; mask off address bits from ready message
	xrl	a,#hpil_rdy_aes	; looking for NES
	jnz	X0a78
	mov	r0,#hpil_sm_d_state
	mov	a,@r0
	anl	a,#hpil_sm_d_state_02
	jnz	X0a79
X0a78:	ret

X0a79:	sel	rb0
	mov	a,r7
	mov	r6,a
	sel	rb1
	mov	@r1,#hpil_sm_aa_state_awps

hpil_sm_aa_awps:
	call	X0e77
	jnz	hpil_sm_aa_goto_aaus
	call	X0ea1
	jz	X0a8e
	mov	a,r2
	anl	a,#0e0h		; mask off address bits from ready message
	xrl	a,#hpil_rdy_aep
	jz	X0a8f
X0a8e:	ret

X0a8f:	mov	a,r2		; write loop addrss register from low 5 bits of R2 (doesn't update R6)
	anl	a,#1fh
	mov	r0,#4
	call	hpil_write_reg

	mov	@r1,#hpil_sm_aa_state_aecs

hpil_sm_aa_aecs:
	call	X0e77
	jnz	hpil_sm_aa_goto_aaus
	ret


; HP-IL T (Talker) state machine, capability T2,3,4
; HP-IL Interface Specification, figure 2-8, TPIS and TPAS states

hpil_sm_tp:
	mov	r1,#28h
	mov	a,@r1
	jb0	hpil_sm_tp_tpis
	jb1	hpil_sm_tp_tpas

hpil_sm_tp_goto_tpis:
	mov	@r1,#hpil_sm_tp_state_tpis
	call	X0ecf

hpil_sm_tp_tpis:
	call	X0d7c
	jz	X0ab3
	mov	r0,#hpil_sm_aa_state
	mov	a,@r0
	anl	a,#hpil_sm_aa_state_aecs
	jnz	hpil_sm_tp_goto_tpas
X0ab3:	ret

hpil_sm_tp_goto_tpas:
	mov	@r1,#hpil_sm_tp_state_tpas
	call	hpil_set_talker_active_if_not_listener

hpil_sm_tp_tpas:
	call	hpil_check_msg_non_data
	jz	X0ac9
	call	X0d7c
	jnz	X0ac9
	call	X0d4a
	jnz	X0ac9
	mov	a,r6
	anl	a,#8
	jz	hpil_sm_tp_goto_tpis
X0ac9:	ret


X0aca:	clr	f0
X0acb:	mov	a,r4
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R4
	outl	p2,a
	movx	a,@r1
	xrl	a,#20h
	jnz	X0ade
	mov	a,r1
	jnz	X0ad8
	dec	r4
X0ad8:	dec	r1
	djnz	r7,X0acb
	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)
	ret

X0ade:	cpl	f0
	movx	a,@r1
	mov	r6,a
	mov	a,r7
	dec	a
	jnz	X0ae9
	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)
	clr	a
	ret

X0ae9:	mov	r6,#20h
X0aeb:	mov	a,r4
	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R4
	outl	p2,a
	movx	a,@r1
	xch	a,r6
	movx	@r1,a
	mov	a,r1
	jnz	X0af6
	dec	r4
X0af6:	dec	r1
	djnz	r7,X0aeb
	orl	p2,#0f0h		; deselect RAM (and HP-IL, CRTC)
	mov	a,#1
	ret


	org	0b00h

; HP-IL L (Listener) state machine
; HP-IL Interface Specification, figure 2-9

hpil_sm_l:
	mov	r1,#hpil_sm_l_state
	mov	a,@r1
	jb0	hpil_sm_l_lids
	jb1	hpil_sm_l_lacs

hpil_sm_l_goto_lids:
	call	hpil_clear_listener
	mov	@r1,#hpil_sm_l_state_lids

hpil_sm_l_lids:
	call	hpil_check_msg_non_data
	jz	X0b25
	call	X0eb4
	jz	X0b1a
	mov	r0,#hpil_sm_aa_state
	mov	a,@r0
	anl	a,#hpil_sm_aa_state_aecs
	jz	hpil_sm_l_goto_lacs
X0b1a:	call	X0d6b
	jz	X0b25
	mov	r0,#hpil_sm_lp_state
	mov	a,@r0
	anl	a,#hpil_sm_lp_state_lpas
	jnz	hpil_sm_l_goto_lacs
X0b25:	ret

hpil_sm_l_goto_lacs:
	call	hpil_set_listener_active
	mov	@r1,#hpil_sm_l_state_lacs

hpil_sm_l_lacs:
	call	X0e51
	jz	X0b4e
	mov	a,r2
	xrl	a,#hpil_cmd_unl
	jz	hpil_sm_l_goto_lids
	mov	a,r2
	xrl	a,#hpil_cmd_ifc
	jz	hpil_sm_l_goto_lids
	call	X0d7c
	jz	X0b43
	mov	r0,#hpil_sm_aa_state
	mov	a,@r0
	anl	a,#hpil_sm_aa_state_aecs
	jz	hpil_sm_l_goto_lids
X0b43:	call	X0d6b
	jz	X0b4e
	mov	r0,#28h
	mov	a,@r0
	anl	a,#2
	jnz	hpil_sm_l_goto_lids
X0b4e:	ret


hpil_set_listener_active_if_not_talker:
	call	hpil_read_status_reg
	anl	a,#20h			; talker active?
	jnz	X0b4e			;   yes, done
hpil_set_listener_active:
	call	hpil_read_status_reg
	anl	a,#0fbh			; clear set local ready
	orl	a,#10h			; set listener active
	jmp	hpil_write_reg


hpil_clear_listener:
	call	hpil_read_status_reg
	anl	a,#0ebh			; clear listener active, clear set local ready
	jmp	hpil_write_reg


; ESC O - delete character
esc_delete_character:
	dis	i
	sel	mb0
	assume	mb:0
	call	X069c
	sel	mb1
	assume	mb:1
	mov	r0,#30h
	mov	a,@r0
	mov	r5,a
	sel	mb0
	assume	mb:0
	call	clear_vert_int_wait_clear
	sel	mb1
	assume	mb:1
	orl	p1,#1		; show display
X0b72:	mov	a,r5
	sel	mb0
	assume	mb:0
	call	X029a
	sel	mb1
	assume	mb:1
	jnz	X0b7c
	inc	r5
	jmp	X0b72

X0b7c:	mov	r0,#3eh
	mov	a,r5
	mov	@r0,a
	inc	r0
	clr	a
	mov	@r0,a
	mov	r6,#20h
	mov	a,r5
	mov	r0,#30h
	xrl	a,@r0
	jz	X0bb9
X0b8b:	call	X0cdf
	call	X0aca
	jf0	X0b9e
	mov	r6,#20h
	mov	r0,#3fh
	inc	@r0
	dec	r5
	mov	a,r5
	mov	r0,#30h
	xrl	a,@r0
	jnz	X0b8b
	inc	r5
X0b9e:	jnz	X0ba7
	mov	a,r5
	dec	a
	mov	r0,#3fh
	inc	@r0
	jmp	X0ba8

X0ba7:	mov	a,r5
X0ba8:	sel	mb0
	assume	mb:0
	call	X00c2
	sel	mb1
	assume	mb:1
X0bac:	dec	r5
	mov	a,r5
	mov	r0,#30h
	xrl	a,@r0
	jz	X0bbe
	call	X0cdf
	call	X0aeb
	jmp	X0bac

X0bb9:	mov	a,r5
	call	X0ce7
	jmp	X0bc0

X0bbe:	call	X0cdf
X0bc0:	mov	r0,#3ch
	mov	a,@r0
	mov	r7,a
	call	X0aeb
	sel	mb0
	assume	mb:0
	call	X06a4
	sel	mb1
	assume	mb:1
	mov	r0,#3fh
	mov	a,@r0
	jnz	X0bd4
	sel	mb0
	assume	mb:0
	call	clear_vert_int
	en	i

	ret


X0bd4:	mov	r1,#42h
	mov	r0,#3ch
	mov	a,@r0
	mov	@r1,a
	inc	r1
	mov	r0,#30h
	mov	a,@r0
	mov	@r1,a
	mov	r1,#3eh
	mov	a,@r1
	mov	@r0,a
	sel	mb0
	assume	mb:0
	call	esc_delete_line
	mov	r1,#42h
	mov	r0,#3ch
	mov	a,@r1
	mov	@r0,a
	inc	r1
	mov	r0,#30h
	mov	a,@r1
	mov	@r0,a
	jmp	X025a


	org	0c00h
	assume	mb:1

; HP-IL T (Talker) state machine, capability T2,3,4
; HP-IL Interface Specification, figure 2-8,
; all states except TPIS and TPAS

hpil_sm_t:
	mov	r1,#hpil_sm_t_state
	mov	a,@r1
	jb0	hpil_sm_t_tids
	jb1	hpil_sm_t_tads
; state 2 not used
	jb3	hpil_sm_t_spas
	jb4	hpil_sm_t_dias
	jb5	hpil_sm_t_aias
	jb6	hpil_sm_t_ters
	jb7	hpil_sm_t_tahs

hpil_sm_t_goto_tids:
	call	hpil_clear_talker
	mov	@r1,#hpil_sm_t_state_tids

hpil_sm_t_tids:
	call	X0d7c
	jz	X0c20
	mov	r0,#25h
	mov	a,@r0
	anl	a,#20h
	jz	hpil_sm_t_goto_tads
X0c20:	call	X0d6b
	jz	X0c2b
	mov	r0,#28h
	mov	a,@r0
	anl	a,#2
	jnz	hpil_sm_t_goto_tads
X0c2b:	ret

hpil_sm_t_goto_tads:
	call	hpil_set_talker_active
	mov	@r1,#hpil_sm_t_state_tads

hpil_sm_t_tads:
	call	hpil_check_msg_non_data_and_frav
	jz	X0c43
	mov	a,r2
	xrl	a,#hpil_rdy_sst
	jz	hpil_sm_t_goto_spas
	mov	a,r2
	xrl	a,#hpil_rdy_sdi
	jz	hpil_sm_t_goto_dias
	mov	a,r2
	xrl	a,#hpil_rdy_sai
	jz	hpil_sm_t_goto_aias

X0c43:	call	X0e51
	jz	X0c75
	call	X0dc6
	jnz	hpil_sm_t_goto_tids
	mov	a,r2
	xrl	a,#hpil_cmd_unt
	jz	hpil_sm_t_goto_tids
	call	X0d99
	jnz	hpil_sm_t_goto_tids
	call	X0d5a
	jz	X0c5f
	mov	r0,#28h
	mov	a,@r0
	anl	a,#2
	jnz	hpil_sm_t_goto_tids
X0c5f:	call	X0eb4
	jz	X0c6a
	mov	r0,#25h
	mov	a,@r0
	anl	a,#20h
	jz	hpil_sm_t_goto_tids
X0c6a:	call	X0d6b
	jz	X0c75
	mov	r0,#26h
	mov	a,@r0
	anl	a,#2
	jnz	hpil_sm_t_goto_tids
X0c75:	ret

hpil_sm_t_goto_spas:
	mov	@r1,#hpil_sm_t_state_spas
	ret

hpil_sm_t_spas:
	jmp	hpil_sm_t_spas_dias_aias

hpil_sm_t_goto_dias:
	mov	@r1,#hpil_sm_t_state_dias
	ret

hpil_sm_t_dias:
	jmp	hpil_sm_t_spas_dias_aias

hpil_sm_t_goto_aias:
	mov	@r1,#hpil_sm_t_state_aias
	ret

hpil_sm_t_aias:
	jmp	hpil_sm_t_spas_dias_aias

hpil_sm_t_goto_ters:
	mov	@r1,#hpil_sm_t_state_ters

hpil_sm_t_ters:
	call	hpil_check_msg_non_data
	jz	X0c8f
	call	X0dc6
	jnz	hpil_sm_t_goto_tids
X0c8f:	mov	r0,#21h
	mov	a,@r0
	anl	a,#8
	jz	X0ca4
	sel	rb0
	mov	a,r1
	xrl	a,#0a0h
	sel	rb1
	jnz	X0ca4
	sel	rb0
	mov	a,r0
	xrl	a,#hpil_rdy_ete
	sel	rb1
	jz	hpil_sm_t_goto_tads
X0ca4:	ret

hpil_sm_t_goto_tahs:
	mov	@r1,#hpil_sm_t_state_tahs

hpil_sm_t_tahs:
	call	hpil_check_msg_non_data
	jz	X0caf
	call	X0dc6
	jnz	hpil_sm_t_goto_tids
X0caf:	mov	r0,#21h
	mov	a,@r0
	anl	a,#8
	jz	X0cc4
	sel	rb0
	mov	a,r1
	xrl	a,#0a0h
	sel	rb1
	jnz	X0cc4
	sel	rb0
	mov	a,r0
	xrl	a,#hpil_rdy_eto
	sel	rb1
	jz	hpil_sm_t_goto_tads
X0cc4:	call	X0fcb
	jnz	hpil_sm_t_goto_ters
X0cc8:	ret


hpil_set_talker_active_if_not_listener:
	call	hpil_read_status_reg
	anl	a,#10h			; listener active?
	jnz	X0cc8			;   yes, done
hpil_set_talker_active:
	call	hpil_read_status_reg
	anl	a,#0fbh			; clear set local ready
	orl	a,#20h			; set talker active
	jmp	hpil_write_reg


hpil_clear_talker:
	mov	r0,#0			; read status register - could call hpil_read_status_reg to save an instruction
	call	hpil_read_reg

	anl	a,#0dbh			; clear talker active, don't clear local ready
	jmp	hpil_write_reg


X0cdf:	mov	r0,#3bh
	mov	a,@r0
	mov	r7,a
	mov	a,r5
	sel	mb0
	assume	mb:0
	call	clear_vert_int_wait_clear
X0ce7:	sel	mb0
	assume	mb:0
	call	X029a
	sel	mb1
	assume	mb:1
	mov	a,r0
	mov	r4,a
	mov	a,r1
	jnz	X0cf1
	dec	r4
X0cf1:	dec	r1
	ret


	org	0d00h

; HP-IL DC (Device Clear) state machine
; HP-IL Interface Specification, figure 2-15

hpil_sm_dc:
	mov	r1,#hpil_sm_dc_state
	mov	a,@r1
	jb0	hpil_sm_dc_dcis
	jb1	hpil_sm_dc_dcas

hpil_sm_dc_goto_dcis:
	mov	@r1,#hpil_sm_dc_state_dcis

hpil_sm_dc_dcis:
	call	X0e51
	jz	X0d1e
	mov	a,r2
	xrl	a,#hpil_cmd_dcl
	jz	hpil_sm_dc_goto_dcas
	mov	a,r2
	xrl	a,#hpil_cmd_sdc
	jnz	X0d1e
	mov	r0,#hpil_sm_l_state
	mov	a,@r0
	anl	a,#hpil_sm_l_state_lacs
	jnz	hpil_sm_dc_goto_dcas
X0d1e:	ret

hpil_sm_dc_goto_dcas:
	mov	@r1,#hpil_sm_dc_state_dcas

hpil_sm_dc_dcas:
	call	hpil_check_msg_non_data
	jz	hpil_sm_dc_goto_dcis
	ret


; T (Talker) SPAS, DIAS, AIAS
hpil_sm_t_spas_dias_aias:
	call	hpil_check_msg_non_data
	jz	X0d30
	call	X0dc6
	jz	X0d30
	assume	mb:1
	jmp	hpil_sm_t_goto_tids

X0d30:	call	X0fcb
	jz	X0d36
	jmp	hpil_sm_t_goto_tahs

X0d36:	sel	mb0
	assume	mb:0
	call	X022f
	sel	mb1
	assume mb:1
	jnz	X0d3e
	jmp	hpil_sm_t_goto_tahs

X0d3e:	call	hpil_check_msg_non_data_and_frav
	jz	X0d49
	mov	a,r2
	xrl	a,#42h		; XXX possibly NRD
	jnz	X0d49
	jmp	hpil_sm_t_goto_tahs

X0d49:	ret

X0d4a:	call	X0e83
	jz	X0d58
	mov	a,r2
	anl	a,#0e0h
	xrl	a,#60h
	jnz	X0d58
	mov	a,#1
	ret

X0d58:	clr	a
	ret

X0d5a:	call	X0d4a
	jz	X0d69
	mov	a,r2
	anl	a,#1fh
	sel	rb0
	xrl	a,r6
	sel	rb1
	jz	X0d69
	mov	a,#1
	ret

X0d69:	clr	a
	ret

X0d6b:	call	X0d4a
	jz	X0d7a
	mov	a,r2
	anl	a,#1fh
	sel	rb0
	xrl	a,r6
	sel	rb1
	jnz	X0d7a
	mov	a,#1
	ret

X0d7a:	clr	a
	ret


X0d7c:	call	X0e83
	jz	X0d97
	mov	a,r2
	anl	a,#0e0h
	xrl	a,#40h
	jnz	X0d97

	mov	r0,#4		; read loop address register
	call	hpil_read_reg
	anl	a,#1fh		; interested in address bits only

	mov	r0,a
	mov	a,r2
	anl	a,#1fh
	xrl	a,r0
	jnz	X0d97
	mov	a,#1
	ret

X0d97:	clr	a
	ret


X0d99:	call	X0e83
	jz	X0db4
	mov	a,r2
	anl	a,#0e0h
	xrl	a,#40h
	jnz	X0db4

	mov	r0,#4		; read loop address register
	call	hpil_read_reg
	anl	a,#1fh		; interested in address bits only

	mov	r0,a
	mov	a,r2
	anl	a,#1fh
	xrl	a,r0
	jz	X0db4
	mov	a,#1
	ret

X0db4:	clr	a
	ret

X0db6:	call	hpil_check_msg_non_data_and_frav
	jz	X0dc4
	mov	a,r2
	anl	a,#0f8h
	xrl	a,#60h
	jnz	X0dc4
	mov	a,#1
	ret

X0dc4:	clr	a
	ret

X0dc6:	mov	a,r7
	anl	a,#10h
	jz	X0dce
	mov	a,#1
	ret

X0dce:	clr	a
	ret


hpil_reset_chip:
	mov	r0,#0		; read status register
	call	hpil_read_reg

	mov	r0,#0		; turn on master clear
	mov	a,#1
	call	hpil_write_reg

	mov	r0,#0		; turn off master clear
	mov	a,#0
	call	hpil_write_reg

	mov	r0,#1		; clear the interrupt register
	mov	a,#0
	call	hpil_write_reg

	mov	r0,#3		; clear the parallel poll reigster
	mov	a,#0
	call	hpil_write_reg	; could be jmp to save one instruction
	ret


; initializes 14 bytes of RAM starting at 20h to 01h
; possibly state machine state variables?
init_ram20:
	mov	r0,#14
	mov	r1,#20h
	mov	a,#01h
X0df3:	mov	@r1,a
	inc	r1
	djnz	r0,X0df3
	mov	r6,#0
	ret


	org	0e00h


hpil_clear_ifcr:
	call	hpil_read_status_reg
	anl	a,#0fbh			; clear set local ready
	orl	a,#2			; set clear IFCR
	jmp	hpil_write_reg


hpil_set_set_local_ready:
	call	hpil_read_status_reg
	orl	a,#4			; set set local ready
	jmp	hpil_write_reg


hpil_read_intr_reg:
	mov	r0,#1			; read HP-IL interrupt register
	call	hpil_read_reg
	mov	r7,a			; save in r7
X0e13:	ret


X0e14:	call	hpil_check_msg_non_data
	jz	X0e1f
	mov	a,r7
	anl	a,#10h
	jz	X0e1f
	call	hpil_clear_ifcr
X0e1f:	call	X0e51
	jz	X0e13
	jmp	hpil_set_set_local_ready


; write HP-IL register selected by R0
hpil_write_reg:
	anl	p2,#0efh		; select HP-IL
	movx	@r0,a
	orl	p2,#0f0h		; deselect HP-IL (and RAM, CRTC)
	ret


; read HP-IL status register (R0)
hpil_read_status_reg:
	mov	r0,#0

; read HP-IL register selected by R0
hpil_read_reg:
	anl	p2,#0efh		; select HP-IL
	movx	a,@r0
	orl	p2,#0f0h		; deselect HP-IL (and RAM, CRTC)
	ret


X0e33:	mov	a,r3
	anl	a,#0e0h
	mov	r4,a
	xrl	a,#80h
	jnz	X0e3e
	mov	r6,#81h
	ret

X0e3e:	mov	a,r4
	xrl	a,#0a0h
	jnz	X0e46
	mov	r6,#84h
	ret

X0e46:	mov	a,r4
	anl	a,#80h
	jz	X0e4e
	mov	r6,#88h
	ret

X0e4e:	mov	r6,#82h
	ret


X0e51:	call	hpil_check_msg_non_data
	jz	ret_a_zero
	mov	a,r6
	anl	a,#1
	jz	ret_a_zero
	mov	a,#1
	ret

ret_a_zero:
	clr	a
	ret


hpil_check_msg_non_data_and_frav:
	call	hpil_check_msg_non_data
	jz	ret_a_zero
	mov	a,r6
	anl	a,#4		; FRAV?
	jz	ret_a_zero
	mov	a,#1
	ret


hpil_check_msg_non_data_and_frns:
	call	hpil_check_msg_non_data
	jz	ret_a_zero
	mov	a,r6
	anl	a,#2		; FRNS?
	jz	ret_a_zero
	mov	a,#1
	ret


X0e77:	call	X0e51
	jz	ret_a_zero
	mov	a,r2
	xrl	a,#9ah
	jnz	ret_a_zero
	mov	a,#1
	ret

X0e83:	mov	a,r6
	anl	a,#80h
	jz	ret_a_zero
	mov	a,r6
	anl	a,#1
	jz	ret_a_zero
	mov	a,r2
	anl	a,#1fh
	xrl	a,#1fh
	jz	ret_a_zero
	mov	a,#1
	ret

X0e97:	mov	a,r2
	anl	a,#1fh
	xrl	a,#1fh
	jz	ret_a_zero
	mov	a,#1
	ret

X0ea1:	call	hpil_check_msg_non_data_and_frav
	jz	ret_a_zero
	call	X0e97
	jz	ret_a_zero
	mov	a,#1
	ret


; inspect remote message, return true if IDY, CMD, or RDY, false if DOE
hpil_check_msg_non_data:
	mov	a,r6
	anl	a,#80h
	jz	ret_a_zero
	mov	a,#1
	ret


X0eb4:	call	X0e83
	jz	ret_a_zero
	mov	a,r2
	anl	a,#0e0h
	xrl	a,#20h
	jnz	ret_a_zero

	mov	r0,#4		; read loop address register
	call	hpil_read_reg
	anl	a,#1fh		; interested in address bits only

	mov	r0,a
	mov	a,r2
	anl	a,#1fh
	xrl	a,r0
	jnz	ret_a_zero
	mov	a,#1
	ret


X0ecf:	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_tids
	jz	X0e13
	jmp	hpil_clear_talker

X0ed8:	mov	r0,#hpil_sm_l_state
	mov	a,@r0
	anl	a,#hpil_sm_l_state_lacs
	jnz	X0e13
	jmp	hpil_clear_listener


X0ee1:	call	hpil_check_msg_non_data_and_frav
	jz	X0eef
	mov	a,r2
	xrl	a,#64h
	jz	X0efc
	mov	a,r2
	xrl	a,#60h
	jz	X0efc
X0eef:	call	hpil_check_msg_non_data_and_frns
	jz	X0efb

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_tids
	jnz	X0efb

	clr	a
X0efb:	ret

X0efc:	inc	a
	ret

	org	0f00h

; state machine 2a

X0f00:	mov	r1,#2ah
	mov	a,@r1
	jb0	X0f0b
	jb1	X0f15
	jb2	X0f35
X0f09:	mov	@r1,#1

X0f0b:	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#0fch
	jnz	X0f13

	ret

X0f13:	mov	@r1,#2
X0f15:	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_tids | hpil_sm_t_state_tads
	jnz	X0f09
	call	hpil_check_msg_non_data
	jz	X0f32
	mov	a,r7
	anl	a,#2
	jz	X0f32
	call	hpil_check_msg_non_data_and_frns
	jz	X0f33
	mov	r0,#37h
	mov	a,@r0
	dec	a
	mov	r0,a
	mov	a,@r0
	xrl	a,r2
	jnz	X0f33
X0f32:	ret

X0f33:	mov	@r1,#4

X0f35:	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#40h
	jnz	X0f13

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_tids | hpil_sm_t_state_tads
	jnz	X0f09
	ret


X0f44:	mov	r1,#hpil_sm_2b_state
	mov	a,@r1
	jb0	hpil_sm_2b_01
	jb1	hpil_sm_2b_02
	jb2	hpil_sm_2b_04
	jb3	hpil_sm_2b_08

hpil_sm_2b_goto_01:
	mov	@r1,#1

hpil_sm_2b_01:
	mov	r0,#hpil_sm_2a_state
	mov	a,@r0
	anl	a,#2
	jz	X0f81
	mov	r0,#hpil_sm_21_state
	mov	a,@r0
	anl	a,#hpil_sm_21_state_02
	jz	X0f81
	mov	r0,#hpil_sm_20_state
	mov	a,@r0
	anl	a,#hpil_sm_20_state_01
	jz	X0f81
	sel	mb0
	assume	mb:0
	call	X022f
	sel	mb1
	assume	mb:1
	jz	X0f73

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_aias | hpil_sm_t_state_dias | hpil_sm_t_state_spas | hpil_sm_t_state_tacs
	jnz	hpil_sm_2b_goto_02

X0f73:	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_tahs
	jnz	hpil_sm_2b_goto_04

	mov	r0,#hpil_sm_t_state
	mov	a,@r0
	anl	a,#hpil_sm_t_state_ters
	jnz	hpil_sm_2b_goto_08

X0f81:	ret

hpil_sm_2b_goto_02:
	sel	mb0
	assume	mb:0
	call	X020e
	mov	a,r4
	sel	mb1
	assume	mb:1
	sel	rb0
	mov	r0,a
	mov	r1,#0
	sel	rb1
	mov	@r1,#hpil_sm_2b_state_02
hpil_sm_2b_02:
	jmp	X0fa4

hpil_sm_2b_goto_04:
	sel	rb0
	mov	r0,#40h
	mov	r1,#0a0h
	sel	rb1
	mov	@r1,#hpil_sm_2b_state_04
hpil_sm_2b_04:
	jmp	X0fa4

hpil_sm_2b_goto_08:
	sel	rb0
	mov	r0,#41h
	mov	r1,#0a0h
	sel	rb1
	mov	@r1,#hpil_sm_2b_state_08
hpil_sm_2b_08:
	jmp	X0fa4

X0fa4:	mov	r0,#hpil_sm_21_state
	mov	a,@r0
	anl	a,#hpil_sm_21_state_08
	jnz	hpil_sm_2b_goto_01
	ret


X0fac:	call	hpil_check_msg_non_data
	jz	X0fb7
	sel	rb0
	mov	a,r5
	anl	a,#7fh
	mov	r5,a
	sel	rb1
	ret


X0fb7:	sel	rb0
	mov	a,r5
	jf1	X0fbe
	orl	a,#80h
	mov	r5,a
X0fbe:	sel	rb1
	ret


; handle DCL, SDC (based on DC state machine)
hpil_clear:
	mov	r0,#hpil_sm_dc_state
	mov	a,@r0
	anl	a,#2		; XXXhpil_sm_dc_state_??
	jz	X0fca

	sel	mb0
	assume	mb:0
	jmp	display_init
	assume	mb:1

X0fca:	ret


X0fcb:	mov	r0,#2ah
	mov	a,@r0
	anl	a,#4
	jz	X0fd5
	mov	a,#1
	ret

X0fd5:	clr	a
	ret

X0fd7:	mov	r0,#hpil_sm_2b_state
	mov	a,@r0
	anl	a,#hpil_sm_2b_state_01
	jnz	X0fe1
	mov	a,#1
	ret

X0fe1:	clr	a
	ret

X0fe3:	mov	r0,a
	mov	a,r4
	jf1	X0feb
	anl	a,#0f7h
	jmp	X0fed

X0feb:	orl	a,#8			; select high half of display RAM
X0fed:	orl	a,#0b0h			; select display RAM, A11..A8 from low nibble of R1
	outl	p2,a
	mov	a,r0
	ret


	end


