;---LED-LAMP-PWM-CONTROLLER------------------------------------------
;Author: Roman Sanzharov
;Date: 11.05.2022
;MC: Attiny13AU
;Options: Reset DISABLED
	  CPU clock frequency 4.8 MHz (internal RC-oscillator)
	  Fuse bytes:  LOW = 0x79
	  	      HIGH = 0xFE
;********************************************************************
;Buttons: 4: Power, Color, Brighter, Darker
;Power: On-Off LEDs
;Color: Change group of LEDs
;Brighter: Increase brightness of LEDs
;Darker: Decrease brightness of LEDs
;--------------------------------------------------------------------

;---DEFINITIONS------------------------------------------------------
.include "tn13def.inc";including description file
.list                 ;listing

.def temp    = R16;register for temporary data

.def Delay1  = R17;1st register for delay
.def Delay2  = R18;2nd register for delay

.equ ValDel1 = 0x60;frequency 4.8 MHz; delay 50 ms = 240'000 ticks (max 54.6 ms)
.equ ValDel2 = 0xEA;4 cycles --> 240'000 / 4 = 60'000 = 0xEA60

.def Pow_flg = R19; "power" flag; 0 - off; 1 - on
.def Col_reg = R20; "color" value register; "white" or "yellow"
.def Brs_cnt = R21; "brightness" counter register [0...9]

.equ White  = 0b10000011; "white" value
.equ Yellow = 0b00100011;"yellow" value

.equ pow_bt = 3; "power" button port number
.equ col_bt = 4; "color" button port number
.equ inc_bt = 2; "brighter" button port number
.equ dec_bt = 5; "darker" button port number
;---END-of-definitions-----------------------------------------------

.cseg;code segment

;---LIST-OF-INTERRUPTS-----------------------------------------------
.org 0x00;reset interrupt
	rjmp Init
.org 0x01;external interrupt
	reti
.org 0x02;pin change interrupt
	reti
.org 0x03;timer overflow interrupt
	reti
.org 0x04;EEPROM-ready interrupt
	rjmp MemRdy
.org 0x05;analog comparator interrupt
	reti
.org 0x06;timer compare match A interrupt
	reti
.org 0x07;timer compare match B interrupt
	reti
.org 0x08;watchdog time-out interrupt
	reti
.org 0x09;ADC conversion complete interrupt
	reti
;---END-of-list-of-interrupts----------------------------------------

;---INITIALISATION---------------------------------------------------
Init:
	ldi temp, RAMEND;stack initialisation
	out SPL, temp   ;

	ldi Pow_flg, 0;default "power" flag value
	clt           ;default "memory ready" flag value
	sei           ;global interrupt enable

	clr temp        ;set address of "color" register in EEPROM
	out EEARL, temp ;
	sbi EECR, EERE  ;get data
	in Col_reg, EEDR;read data

	ldi temp, 1     ;set address of "brightness" register in EEPROM
	out EEARL, temp ;
	sbi EECR, EERE  ;get data
	in Brs_cnt, EEDR;read data

Init_PortB:
	ldi temp, 0b00000011;PB0, PB1 - outputs (PWM); PB2...PB5 - inputs (buttons)
	out DDRB, temp
	ldi temp, 0b00111100;pullup resistors on PB2...PB5
	out PORTB, temp
Init_TC0:
	ldi temp, 0b00000011;frequency 4.8 MHz; timer prescaller = 64
	out TCCR0B, temp    ;timer clock = 75 kHz; PWM = 75 kHz / 256 = 293 Hz

	out TCCR0A, Col_reg;switch color

	ldi temp, 0b00000011;
	out TCCR0A, temp    ;initially timer is off
;---END-of-initialisation--------------------------------------------

;---MAIN-CYCLE-------------------------------------------------------
Start:
	sbis PINB, pow_bt;"power" button pressed? No - skip
	rcall Power      ;Yes - go to Power supprogramm
	cpi Pow_flg, 1   ;"power" flag = 1?
	brne Start       ;No - wait

	sbis PINB, col_bt;"color" button pressed? No - skip
	rcall Color      ;Yes - go to Color subprogramm

	sbis PINB, inc_bt;"brighter" button pressed? No - skip
	rcall BrInc      ;Yes - go to BrInc subprogramm

	sbis PINB, dec_bt;"darker" button pressed? No - skip
	rcall BrDec      ;Yes - go to BrDec subprogramm
	rjmp Start
;---END-of-main-cycle------------------------------------------------

;---POWER-SUBPROGRAMM------------------------------------------------
Power:
	rcall Delay;go to Delay supprogramm

	inc Pow_flg   ;increment "power" flag
	cpi Pow_flg, 2;"power" flag = 2?
	brne PC + 2   ;No - skip
	clr Pow_flg   ;Yes - clear "power" flag

	cpi Pow_flg, 1;"power" flag = 1?
	brne Timer_off;No - switch timer off
	Timer_on:     ;Yes - swithc timer on
	out TCCR0A, Col_reg;turn the timer on
	rcall BrsRead      ;go to BrsRead subprogramm
	rjmp Pow_rel

	Timer_off:
	ldi temp, 0b00000011;
	out TCCR0A, temp    ;turn the timer off

	Pow_rel:
	sbis PINB, pow_bt;"power" button released?
	rjmp Pow_rel     ;No - wait
	rcall Delay      ;Yes - go to Delay supprogramm

	ret;return from subprogramm
;---END-of-power-subprogramm-----------------------------------------

;---COLOR-SUBPROGRAMM------------------------------------------------
Color:
	rcall Delay;go to Delay supprogramm

	inc Col_reg            ;increment "color" register
	cpi Col_reg, White + 1 ;"color" register = "white" value + 1?
	brne PC + 2            ;No - skip
	ldi Col_reg, Yellow    ;Yes - load "yellow" value
	cpi Col_reg, Yellow + 1;"color" register = "yellow" value + 1?
	brne PC + 2            ;No - skip
	ldi Col_reg, White     ;Yes - load "white" value

	out TCCR0A, Col_reg;set color
	
	clr temp         ;set "color" register
	out EEARL, temp  ;address in EEPROM
	out EEDR, Col_reg;set "color" data to be saved
	sbi EECR, EEMPE  ;enable writing
	sbi EECR, EEPE   ;
	sbi EECR, EERIE  ;enable EEPROM-ready interrupt
	
	ColMemWait:    ;
	brtc ColMemWait;"memory ready" flag = 1? No - wait
	cbi EECR, EERIE;Yes - disable EEPROM-ready interrupt
	clt            ;and clear "memory ready" flag

	Col_rel:
	sbis PINB, col_bt;"color" button released?
	rjmp Col_rel     ;No - wait
	rcall Delay      ;Yes - go to Delay supprogramm

	ret;return from subprogramm
;---END-of-color-subprogramm-----------------------------------------

;---BRIGHTNESS-INCREMENT-SUBPROGRAMM---------------------------------
BrInc:
	rcall Delay;go to Delay supprogramm

	inc Brs_cnt    ;increment "brightness" counter register
	cpi Brs_cnt, 10;"brightness" counter value = 10?
	brne PC + 3    ;No - skip
	ldi Brs_cnt, 9 ;Yes - constarin value
	rjmp BrsIncRel ;and skip saving

	rcall BrsRead;go to BrsRead subprogramm

	rcall BrsSave;go to BrsSave subprogramm

	BrsIncRel:
	sbis PINB, inc_bt;"brighter" button released?
	rjmp BrsIncRel   ;No - wait
	rcall Delay      ;Yes - go to Delay supprogramm

	ret;return from subprogramm
;---END-of-brightness-increment-subprogramm--------------------------

;---BRIGHTNESS-DECREMENT-SUBPROGRAMM---------------------------------
BrDec:
	rcall Delay;go to Delay supprogramm

	dec Brs_cnt     ;decrement "brightness" counter register
	cpi Brs_cnt, 255;"brightness" counter value = -1 = 255?
	brne PC + 3     ;No - skip
	clr Brs_cnt     ;Yes - constarin value
	rjmp BrsDecRel  ;and skip saving

	rcall BrsRead;go to BrsRead subprogramm
	
	rcall BrsSave;go to BrsSave subprogramm

	BrsDecRel:
	sbis PINB, dec_bt;"darker" button released?
	rjmp BrsDecRel   ;No - wait
	rcall Delay      ;Yes - go to Delay supprogramm

	ret;return from subprogramm
;---END-of-brightness-decrement-subprogramm--------------------------

;---DELAY-SUBPROGRAMM------------------------------------------------
Delay:
	ldi Delay1, ValDel1;load delay values
	ldi Delay2, ValDel2;
	Cycle:
	subi Delay1, 1;
	sbci Delay2, 0;decrement till 0
	brcc Cycle    ;

	ret;return from subprogramm
;---END-of-delay-subprogram------------------------------------------

;---BRIGHTNESS-READ-SUBPROGRAMM--------------------------------------
BrsRead:
	ldi ZL, low(TABLE * 2) ;
	ldi ZH, high(TABLE * 2);
	add ZL, Brs_cnt        ;read PWM values from TABLE
	clr temp               ;
	adc ZH, temp           ;

	lpm temp, Z            ;
	out OCR0A, temp        ;set PWM duty
	out OCR0B, temp        ;

	ret;return from subprogramm
;---END-of-brightness-read-subprogramm-------------------------------

;---MEMORY-READY-INTERRUPT-------------------------------------------
MemRdy:
	set ;set "memory ready" flag
	reti;return from interrupt subprogramm
;---END-of-memory-ready-interrupt------------------------------------

;---BRIGHTNESS-SAVE-SUBPROGRAMM--------------------------------------
BrsSave:
	ldi temp, 1      ;set "brightness" counter  
	out EEARL, temp  ;register address in EEPROM
	out EEDR, Brs_cnt;set "brightness" counter data
	sbi EECR, EEMPE  ;enable writing
	sbi EECR, EEPE   ;
	sbi EECR, EERIE  ;enable EEPROM-ready interrupt
	
	MemWait:
	brtc MemWait   ;"memory ready" flag = 1? No - wait
	cbi EECR, EERIE;Yes - disable EEPROM-ready interrupt
	clt            ;and clear "memory ready" flag

	ret;return from subprogramm
;---END-of-brightness-save-subprogramm-------------------------------

;---BRIGHTNESS-CONVERTATION-TABLE------------------------------------
TABLE:
.db 25,  50 ;PWM values for 0 & 1 "brightness" counter values
.db 75,  100;PWM values for 2 & 3 "brightness" counter values
.db 125, 150;PWM values for 4 & 5 "brightness" counter values
.db 175, 200;PWM values for 6 & 7 "brightness" counter values
.db 225, 250;PWM values for 8 & 9 "brightness" counter values
;---END-of-brightness-conversation-table-----------------------------

;---TABLE-OF-INITIAL-COLOR-AND-BRIGHTNESS-DATA-IN-EEPROM-------------
.eseg       ;EEPROM data segment
.org 0x00   ;set address of data in EEPROM
.db White, 0;list of initial data
;---END-OF-TABLE-----------------------------------------------------
