; This is a "functional" TSR Code By Roy Massaad
; it is supposed to hook to int 10h (the video one) functions (9,10,14)
; check for the 9 character and replace it with some other (6)
; also it must know if it is already resident ,and how to unload

; plz check int 21h functions (25,35,31,4c,49,62)h documentation before continuing
; and the INT 2fh, better known as the MultiPlexer

.286

.model large

.stack 10h

.code

; so let's set up the constants shall we !

cr	equ 	13	; ascii representation for line feed & carriage return
lf	equ	10

video	equ	10h
dos	equ	21h
getvector   equ     35h
setvector   equ     25h
settsr	    equ     31h
getpsp	    equ     62h
nexit	equ	4ch
killmem	equ	49h
mux	equ	2fh
prog_id equ	3620h		 ; a randomly chosen 16 bit nb as an ID for the program


; let's anchor the start of the code here

soc:

; let's reserve some bytes for the seg:off of the original interrupts
old_int10	dd	0
old_mux		dd	0
psp		dw	0	;to hold the psp seg address

; this here section is concerned with checking and rerouting interrupt calls

new_code:	; bios video int 10h is what we'r hooking with here

        cmp ah,9            ; we check to see if our requested fcts are called
	je switch_board

        cmp ah,10           ; 3 functions concerned with writing a character
	je switch_board

	cmp ah,14	    ; look, a back jump !!
	jne call_old

switch_board:

	cmp al,'9'	    ; if everything OK we do the switch next
	jne call_old
	mov al,'6'

call_old:
	jmp dword ptr old_int10    ;we now return control to the old hag


; here we put our interrupt handler code for the MUX int
; MUX int is used by many programs as a dummy "hooker" int for status check
; it is made up of a chain/stack of code ,cascading .
new_mux:

	; note the use of bx(16) instead of al(8) for the Id with Mux
	cmp bx,prog_id		;ok is the caller our clone ?
	jne exit_newmux

	; 0 in ah means status check while a 1 means unload
	cmp ah,0
	je status_check
	
	cmp ah,1
	je unload
	
exit_newmux:
	jmp dword ptr old_mux	; ok call the next in the chain

status_check:
	mov ax,prog_id
	iret			; set the id and do a normal int return

unload:	
	; before attempting to unhook, let's see if someone else hooked the int10
								; after us
	mov ah,getvector
	mov al,video
	int dos		;now let's compare ur code seg addr with that of cur int10
	mov ax,es
	mov bx,cs
	cmp ax,bx
	jne error_exit
	
	; now we check in 2f
	
	mov ah,getvector
	mov al,mux
	int dos
	mov ax,es
	mov bx,cs
	cmp ax,bx
	jne error_exit
	
	; if everything ok then time to remove the crap from mem
	; first off we will restore old int vectors
	; we start by the int 10

	mov dx, word ptr old_int10 + 0
	mov ds, word ptr old_int10 + 2
	mov ah,setvector
	mov al,video
	int dos
	
	; then we restore int 2f
	mov dx, word ptr old_mux + 0
	mov ds, word ptr old_mux + 2
	mov ah,setvector
	mov al,mux
	int dos

	; then we kill the code starting at psp

	mov es,psp
	mov ah,killmem
	int dos
	
	; then we return ,( look no error code :) )
	mov bl,0	; error code - 0 as in okdoky
	iret

error_exit:
	mov bl,1	; error code - 1 as in big trouble
	iret


;now we anchor the end of the relevant code +
;this is the code entry point concerned with rendering the code resident

entry_point:

; let's define display strings here, out of the tsr memory range

installed_msg	db cr,lf,'TSRVID INSTALLED',cr,lf,'$'

unknown_msg	db cr,lf,'TSRVID already installed',cr,lf,'$'

cant_unload_msg	db cr,lf,'TSRVID cant be unloaded',cr,lf,'$'

unload_success	db cr,lf,'TSRVID unloaded',cr,lf,'$'

	; so lets start by getting the psp using ft 62h ,int 21
	; we gonna need it many times (2)
	
	mov ah,getpsp	; get psp of the current program
	int dos
	mov psp,bx	;the result comes in bx,we save it in psp for later use
	
	
	; then let's check if we have a resident copy
	
	mov ah,0	; status check function
	mov bx,prog_id	; ur program ID
	int mux
	
	; if our tsr is present then we should get Prog_Id in AX

	cmp ax,prog_id
	jne install_tsr	;if not go install it damn it !!!

	; if so let's check the parameters for an U as in Unload
	; the first non blank byte of the parameters is at psp:[82h]
	
	; i'm gonna use a string instructions to retrieve it first

	mov ds,psp
	mov si,82h
	lodsb		; remember how to use this instruction ? :)
	
	; now that the character is in al ,i'll change it to uppercase
	and al,5fh	; very cool trick, only works with a-z

	; and compare it

	cmp al,"U"
	
        je unload_end ;if so prepare to unload calling the mux int hook, fct 1
	
	
	; if parameter unknown then display error msg and exit
	
	mov dx,offset unknown_msg
	call display_msg
	jmp exit_point
		
unload_end:		
	
	mov ah,1
	mov bx,prog_id
	int mux		
	cmp bl,0	; did everthing go ok ?
	je success	

	; if not then display appropriate message
	mov dx,offset cant_unload_msg
	call display_msg
	jmp exit_point	


success:
	mov dx,offset unload_success
	call display_msg
	jmp exit_point	;politicaly correct,suppose i have many parameters?
	
exit_point:
	mov ah,nexit
	mov al,0	;force error code
	int dos


install_tsr:
; let's get the original interupt 10h address and replace it  :)

	mov ah,getvector	;getting it
	mov al,video
	int dos 		;the result will be in es:bx
	mov word ptr old_int10 + 0 ,bx	; we save it in that order
	mov word ptr old_int10 + 2 ,es

	;now we change the vector to point to us !!!

	mov dx,offset new_code	; our seg:(ep off) in the form of ds:dx
	mov ax,cs
	mov ds,ax

	mov ah,setvector
	mov al,video
	int dos

; good, now we do the same to mux int 2f

	mov ah,getvector
	mov al,mux
	int dos
	mov word ptr old_mux + 0 ,bx
	mov word ptr old_mux + 2 ,es	; we saved it
	
	; now we change the table
	
	mov ax,cs
	mov ds,ax
	mov dx,offset new_mux
	mov ah,setvector
	mov al,mux
	int dos				; cool we did it too !


;now we must find the starting address of ur copy of the ENV table and kill it
;in order to make the tsr stealthy and smaller
;it is at psp:[2ch], 
	
	mov ds,psp	; we already got the psp address at entry_point	

; now we kill that range putting it in es and calling 49h int21

	mov ah,killmem
	mov es,ds:[2ch]
	int dos

; now that int10h vector points to us we must terminate but stay resident
; but before let's celebrate this event by displaying a message

	mov dx,offset installed_msg
	call display_msg

; for that we must now get the size of the code before issuing the correct int31h
; the real size is that of our code + PSP (program segment prefix)
; the size is in paragraphs of 16 byte each with the psp being = to 17 prghs
; hence total since is (code in bytes/16)+17 in dx

	mov ah,settsr
	mov al,0	     ; exit code ,dont know what exactly ?!
	mov dx,(((offset entry_point) - (offset soc))/16)+17
	int dos 	     ; and voila !!!


; this function has the sole purpose of displaying passed(by dx) strings

display_msg:	

	push ds
	mov ax,cs
	mov ds,ax
	mov ah,9	;fct 9,int 21 for displaying strings
	int dos
	pop ds		; i pop ds back after dos trash it

	ret
	
; and finish off this crap

end	entry_point	;(not new_code !, ok )
