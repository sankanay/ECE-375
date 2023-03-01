;***********************************************************
;* This is the skeleton file for Lab 5 of ECE 375
;*
;* Author: Yash Sankanagouda & Jim Landers
;*   Date: 2/22/2023
;*
;***********************************************************

.include "m32U4def.inc" ; Include definition file

;***********************************************************
;* Internal Register Definitions and Constants
;***********************************************************
.def mpr = r16 ; Multi-Purpose Register
.def waitcnt = r17 ; Wait Loop Counter
.def ilcnt = r18 ; Inner Loop Counter
.def olcnt = r19 ; Outer Loop Counter
.def left_counter = r15 ;
.def right_counter = r23

.equ WTime = 80 ; Time to wait in wait loop

.equ WskrR = 4 ; Right Whisker Input Bit
.equ WskrL = 5 ; Left Whisker Input Bit
.equ EngEnR = 5 ; Right Engine Enable Bit
.equ EngEnL = 6 ; Left Engine Enable Bit
.equ EngDirR = 4 ; Right Engine Direction Bit
.equ EngDirL = 7 ; Left Engine Direction Bit

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////

.equ MovFwd = (1<<EngDirR|1<<EngDirL) ; Move Forward Command
.equ MovBck = $00 ; Move Backward Command
.equ TurnR = (1<<EngDirL) ; Turn Right Command
.equ TurnL = (1<<EngDirR) ; Turn Left Command
.equ Halt = (1<<EngEnR|1<<EngEnL) ; Halt Command

;***********************************************************
;* Start of Code Segment
;***********************************************************
.cseg ; Beginning of code segment

;***********************************************************
;* Interrupt Vectors
;***********************************************************
.org $0000 ; Beginning of IVs
	rjmp INIT ; Reset interrupt

; Set up interrupt vectors for any interrupts being used
.org $0002
	rcall HitRight ; Call hit right function
	reti ; Return from interrupt
.org $0004
	rcall HitLeft ; Call hit left function
	reti
; This is just an example:
;.org $002E ; Analog Comparator IV
; rcall HandleAC ; Call function to handle interrupt
; reti ; Return from interrupt

.org $0056 ; End of Interrupt Vectors

;***********************************************************
;* Program Initialization
;***********************************************************
INIT: ; The initialization routine

		; Initialize Stack Pointer
		ldi mpr, LOW(RAMEND)
		out SPL, mpr
		ldi mpr, HIGH(RAMEND)
		out SPL, mpr

		; Initialize LCD Display
		rcall LCDInit
		rcall LCDBacklightOn
		rcall LCDClr

		; clear counters for left and right whisker
		clr left_counter
		clr right_counter

		; Initialize Port B for output
		ldi mpr, $FF
		out DDRB, mpr
		ldi mpr, $00
		out PORTB, mpr

		; Initialize Port D for input
		ldi mpr, $00
		out DDRD, mpr
		ldi mpr, $FF
		out PORTD, mpr

		; Initialize external interrupts
		; Set the Interrupt Sense Control to falling edge
		ldi mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)
		sts EICRA, mpr

		; Configure the External Interrupt Mask
		ldi mpr, (1<<INT0)|(1<<INT1)
		out EIMSK, mpr

		; Turn on interrupts
		SEI
		; NOTE: This must be the last thing to do in the INIT function

;***********************************************************
;* Main Program
;***********************************************************
MAIN:
		
		; Initialize TekBot Forward Movement
		ldi mpr, MovFwd ; Load Move Forward Command
		out PORTB, mpr ; Send command to motors
		rjmp MAIN ; Continue through main

;----------------------------------------------------------------
; Sub: HitRight
; Desc: Handles functionality of the TekBot when the right whisker
; is triggered.
;----------------------------------------------------------------

HitRight:

		ldi mpr, 0 ; load to-be-converted value into mpr
		inc left_counter ; increment when whisker is hit
		mov mpr, left_counter ; move to register to be displayed
		ldi XL, low($0114) ; load X with beginning address
		ldi XH, high($0114) ; of where result will be stored

		rcall Bin2ASCII ; convert from binary to readable number
		rcall LCDWrLn2 ; display onto LCD 2nd line
		
		push mpr ; Save mpr register
		push waitcnt ; Save wait register
		in mpr, SREG ; Save program state
		push mpr 

		; Move Backwards for a second
		ldi mpr, MovBck ; Load Move Backward command
		out PORTB, mpr ; Send command to port
		ldi waitcnt, WTime ; Wait for 1 second
		rcall Wait ; Call wait function

		; Turn left for a second
		ldi mpr, TurnL ; Load Turn Left Command
		out PORTB, mpr ; Send command to port
		ldi waitcnt, WTime ; Wait for 1 second
		rcall Wait ; Call wait function

		ldi mpr, $03
		out EIFR, mpr

		pop mpr ; Restore program state
		out SREG, mpr ;
		pop waitcnt ; Restore wait register
		pop mpr ; Restore mpr
		ret ; Return from subroutine

;----------------------------------------------------------------
; Sub: HitLeft
; Desc: Handles functionality of the TekBot when the left whisker
; is triggered.
;----------------------------------------------------------------
HitLeft:

		ldi mpr, 0 ; load to-be-converted value into mpr
		inc right_counter ; increment when whisker is hit
		mov mpr, right_counter ; move to register to be displayed
		ldi XL, low($0112) ; load X with beginning address
		ldi XH, high($0112) ; of where result will be stored

		rcall Bin2ASCII ; convert from binary to readable number
		rcall LCDWrLn2 ; display onto LCD 2nd line

		push mpr ; Save mpr register
		push waitcnt ; Save wait register
		in mpr, SREG ; Save program state
		push mpr ;

		; Move Backwards for a second
		ldi mpr, MovBck ; Load Move Backward command
		out PORTB, mpr ; Send command to port
		ldi waitcnt, WTime ; Wait for 1 second
		rcall Wait ; Call wait function

		; Turn right for a second
		ldi mpr, TurnR ; Load Turn Left Command
		out PORTB, mpr ; Send command to port
		ldi waitcnt, WTime ; Wait for 1 second
		rcall Wait ; Call wait function

		ldi mpr, $03
		out EIFR, mpr

		pop mpr ; Restore program state
		out SREG, mpr ;
		pop waitcnt ; Restore wait register
		pop mpr ; Restore mpr
		ret ; Return from subroutine

;----------------------------------------------------------------
; Sub: Wait
; Desc: A wait loop that is 16 + 159975*waitcnt cycles or roughly
; waitcnt*10ms.  Just initialize wait for the specific amount
; of time in 10ms intervals. Here is the general eqaution
; for the number of clock cycles in the wait loop:
; (((((3*ilcnt)-1+4)*olcnt)-1+4)*waitcnt)-1+16
;----------------------------------------------------------------
Wait:
		push waitcnt ; Save wait register
		push ilcnt ; Save ilcnt register
		push olcnt ; Save olcnt register

Loop:	ldi olcnt, 224 ; load olcnt register
OLoop:	ldi ilcnt, 237 ; load ilcnt register
ILoop:	dec ilcnt ; decrement ilcnt
		brne ILoop ; Continue Inner Loop
		dec olcnt ; decrement olcnt
		brne OLoop ; Continue Outer Loop
		dec waitcnt ; Decrement wait
		brne Loop ; Continue Wait loop

		pop olcnt ; Restore olcnt register
		pop ilcnt ; Restore ilcnt register
		pop waitcnt ; Restore wait register
		ret ; Return from subroutine


;***********************************************************
;* Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
