# Start of the data section
.data			
.align 4						# To make sure we start with 4 bytes aligned address (Not important for this one)
SEED:
	.word 0x1234				# Put any non zero seed
	
# The main function must be initialized in that manner in order to compile properly on the board
.text
.globl	main
main:

	# Put your initializations here
	li s0, 0					# Initializes s0 to be 0
	li s1, 0x7ff60000 			# assigns s1 with the LED base address (Could be replaced with lui s1, 0x7ff60)
	li s2, 0x7ff70000 			# assigns s2 with the push buttons base address (Could be replaced with lui s2, 0x7ff70)
	li x8, 4
	addi x23, zero, 0
	addi s3, x0, 0x1
	addi s8, x0, 0
	addi s10, x0, 10
	
	
	
	
here1:


	# Enabling Interrupts from core side
	csrrsi zero, mstatus, 0x08 	#enable global interrupt
	
	csrrsi zero, 0x7C0, 0x02 	#enable push button interrupt line from core side	

	# Enable a specific push button interrupt from the PIO side (Check Appendix B)
	addi s4, x0, 2			#interruptmask instruction
	
	addi s5, s2, 0x8
	
	sw s4, 0(s5)
	
	
	# Write your functional code here
	
	# all eight LEDs flash on and off at a rate of 1Hz
	Flashing:
	sw x0, 0(s1) # turns off leds
	
	addi a0, zero, 10
	jal x1, DELAY
	
	#flash all leds at once - active low
	addi a4, x0, 0xff
	sw a4, 0(s1)
	
	#delay for 1hz flashing
	addi a0, zero, 10
	jal x1, DELAY
	
	sw s3,0(s1)
	#if s0 is non zero, get out of Flashing
	beq x0, x0, Flashing
	

out:	
add a7, zero, s0	#a7 now contains scaled value from ISR

#displaying random num after ISR was called due to pressing PB2
DISPLAY_BYTE:

sw a7, 0(s1)	

#1-sec delay
addi a0, x0, 20	

jal x1, DELAY

#DELAYING and DECREMENTING by 10 until we hit a number zero or less
addi a7, a7, -10

bgt a7, zero, DISPLAY_BYTE
	
j here1


jr ra



# Subroutines						
DELAY:
	# Insert your code here to make a delay of a0 * 0.1 s
	li t1, 0x98968
	
	mul t1, t1, a0
	
	wait:
		add t1, t1, -1
		
		bne zero,t1, wait
		
	jr ra


RANDOM_NUM:
	# This is a provided pseudo-random number generator no need to modify it, just call it using JAL (the random number is saved at a0)
	addi sp, sp, -4				# push ra to the stack
	sw ra, 0(sp)
	
	lw t0, 0(gp)				# load the seed or the last previously generated number from the data memory to t0
	li t1, 0x8000
	and t2, t0, t1				# mask bit 16 from the seed
	li t1, 0x2000
	and t3, t0, t1				# mask bit 14 from the seed
	slli t3, t3, 2				# allign bit 14 to be at the position of bit 16
	xor t2, t2, t3				# xor bit 14 with bit 16
	li t1, 0x1000		
	and t3, t0, t1				# mask bit 13 from the seed
	slli t3, t3, 3				# allign bit 13 to be at the position of bit 16
	xor t2, t2, t3				# xor bit 13 with bit 14 and bit 16
	li t1, 0x400
	and t3, t0, t1				# mask bit 11 from the seed
	slli t3, t3, 5				# allign bit 14 to be at the position of bit 16
	xor t2, t2, t3				# xor bit 11 with bit 13, bit 14 and bit 16
	srli t2, t2, 15				# shift the xoe result to the right to be the LSB
	slli t0, t0, 1				# shift the seed to the left by 1
	or t0, t0, t2				# add the XOR result to the shifted seed 
	li t1, 0xFFFF				
	and t0, t0, t1				# clean the upper 16 bits to stay 0
	sw t0, 0(gp)				# store the generated number to the data memory to be the new seed
	mv a0, t0					# copy t0 to a0 as a0 is always the return value of any function
	
	lw ra, 0(sp)				# pop ra from the stack
	addi sp, sp, 4
	jr ra


# Interrupt Service Routine
.text
.globl	isr
isr:
	# De-bouncing (Due to the bouncing of mechanical switches, we need to de-bounce it to avoid entering the ISR many times for the same button press)
	li t1, 2000000
	debounce:
		addi t1, t1, -1
		bne t1, zero, debounce
		
		
	#Edgecapture instruction to acknowledged / handling exception
	
	addi s6, x0, 2
	
	addi s7, s2, 0xc
	
	sw s6, 0(s7)
	
		
	# Generate a number from 50 t0 255 and put it in S0	(You shouldn't call the RANDOM_NUM here, you should have called it in the main already and saved it in some register, you just need to make it fit the 50-255 requirement and save it to s0)
	

	jal x1, RANDOM_NUM
	
	#calculating the scaling factor 40/13107
	addi a5, x0, 0x28
	
	addi t4, zero, 0
	
	li t5, 0x00003333
	
	mul t4, a0, a5
	
	div s0, t4,t5 
	

	# Wait until store takes place and read by the PIO
	
	
	NOP
	NOP
	NOP
	NOP
	NOP 
	NOP
jal x1, out
	
mret	
