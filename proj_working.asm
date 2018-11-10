.data
input_dir: .asciiz "test5.bmp"
output_dir: .asciiz "test_result.bmp"
prompt: .asciiz "\n Starting filtering"
prompt_end: .asciiz "\n End filtering\n"

		.align 2
buffer: .space 2000000

		.align 2
output_buffer: .space 2000000

kernel:
		.align 2
		.space 9		


.text
main:
#	j open_files
	
open_files:

	li $v0, 13		  #open file
	la $a0, input_dir 
	li $a1, 0
	syscall

	move $s0, $v0	#save file descriptor

	bltz $s0, exit  #couldn't open a file
	
	li $v0, 13			#open file
	la $a0, output_dir 
	li $a1, 9
	syscall

	move $s5, $v0	#save file descriptor
	
	subiu $sp, $sp, 20
	sw $s0, 0($sp)
	sw $s5, 4($sp)

	bltz $s5, exit  #couldn't open a file	

read_and_save_image_info:
	#$s0 -> input_image descriptor/ changes later to sum of values of kernel
	#$s1 -> address of buffer
	#$s2 -> height
	#$s3 -> width
	#$s4 -> kernel adress
	#$s5 -> output_file descriptor
	#$s7 -> size of image	
	la $s1, buffer  #header
	
			
	li   $v0, 14 		#read first part of header
	move $a0, $s0		#decsriptor
	move $a1, $s1   	#header	
	li   $a2, 14
	syscall
		
	li $v0, 15 #write to file first part of a header
	move $a0, $s5
	move $a1, $s1
	li   $a2, 14
	syscall
	
	
	lhu $t0, 12($s1)#offset to image from beggining
	sll $t0, $t0, 16 #shifing due to 2 bytes of file iformation and disalignment of data
	lhu $t1, 10($s1)
	addu $t0, $t0, $t1
	subiu $s7, $t0, 14 #next_info part of the file in bytes
		
	li   $v0, 14		#read next part of info
	move $a0, $s0		#decsriptor
	move $a1, $s1  		#other info	buffer
	move $a2, $s7
	syscall

	li $v0, 15 #write to file second part of a header
	move $a0, $s5
	move $a1, $s1
	move $a2, $s7
	syscall
	
	lw $s2, 8($s1) # height
	sw $s2, 8($sp)
	lw $s3, 4($s1) # width
	sw $s3, 12($sp)
	lw $s7, 20($s1) # size of an image
	sw $s7, 16($sp)

prepare_kernel:
	la $s4, kernel
	
    li $t0, 0
	sb $t0, 0($s4)
	li $t0, -1
	sb $t0, 1($s4)
	li $t0, 0
	sb $t0, 2($s4)
	li $t0, -1
	sb $t0, 3($s4)
	li $t0, 5
	sb $t0, 4($s4)
	li $t0, -1
	sb $t0, 5($s4)
	li $t0, 0
	sb $t0, 6($s4)
	li $t0, -1
	sb $t0, 7($s4)
	li $t0, 0
	sb $t0, 8($s4)

		
	li $s0, 0 #sum of all kernel values accumulator
	move $t1, $s4 #kernell adress
	
	move $t0, $zero #counter
loop:	
		lb $t2, 0($t1)
		addu $s0, $s0, $t2
		addiu $t1, $t1, 1
		addiu $t0, $t0, 1
		blt   $t0, 9  loop
	
	
#################################################
#READING IMAGE
#################################################



	

		
read_block:
	li   $v0, 14		#read imgage
	lw   $a0, 0($sp)	#decsriptor
	la   $a1, buffer  	#buffer	
	lw   $a2, 16($sp)	#size of a block

	syscall
	
	#close input file when block reading can't do this
	li $v0, 16
	syscall
	
prepare_filter:
	li $v0, 4
	la $a0, prompt
	syscall

	la $s1, output_buffer
	la $s2, buffer
	
	lw $t8, 8($sp) #rows
	lw $t9, 12($sp)#columns
	
	div $t0, $t9, 4
	mfhi $s3 #<---- padding for each row
			
	mulu $s4, $t9, 3 # whole row of pixels in bytes
	addu $s4, $s4, $s3 #plus padding
		
	li $s5, 0 # ROW counter
	li $s6, 0 # COLUMN counter
	
	addi $t8, $t8, -1 #NRows ignoring edges
	addi $t9, $t9, -2 #NColumns ignoring edges
	mulu $t9, $t9, 3

	#$t0 -> color byte(R or B or G)
	
	#s0 -> kernel sum
	#s1 -> output pointer
	#s2 -> input pointer
	#s3 -> padding for each row
	#s4 -> whole row in bytes
	#s5 -> row counter
	#s6 -> column counter


start_filtering:
#load_first_row:
    move $a2, $s2 #saving whole first row
    move $a1, $s1 
	jal save_row
	addu $s2, $s2, $s4 #moving pointers
	addiu $s2, $s2, 3
	addu $s1, $s1, $s4 #forward
	addiu $s1, $s1, 3
	li 	  $s5, 1
	
	lbu $t6, -3($s2) 
	sb $t6, -3($s1)
	lbu $t6, -2($s2) 
	sb $t6, -2($s1)
	lbu $t6, -1($s2) 
	sb $t6, -1($s1)
	
next_image_row:
		li $s6, 0 # reseting byte counter
		bgeu $s5, $t8, save_result #checking if all rows are done
next_image_color:	
			addiu $s6, $s6, 1 #next byte
			bgtu $s6, $t9, next_row

			li $t3, 0 #accumulator of suma ważona
			
			la $t4,	  kernel  #kernel tile
			move $t5, $s2     #current byte
			
			subiu $t5, $t5, 3	#starting with left column
			subu  $t5, $t5, $s4 #and bottom row
			
			#setting up loop counters
			li $a1, 3 #column counter
			li $a2, 3 #row counter
		
		
		next_kernel_row:
			lbu $t6, 0($t5)     #value of color of the pixel
			lb $t7, 0($t4)		#value of kernel tile
			
			mul $t6, $t6, $t7	#calculate cooeficient
			add $t3, $t3, $t6	#add cooeficient into accumulator
			
			addiu $t4, $t4, 1
			addiu $t5, $t5, 3 #next pixel
			
			subiu $a1, $a1, 1
			bgtz $a1, next_kernel_row
		next_kernel_column:
			subiu $t5, $t5, 9 # returning to first column
			addu $t5, $t5, $s4	#going up a row
			
			subiu $a2, $a2, 1
			li $a1, 3
			
			bgtz $a2, next_kernel_row
			
		addiu $s2, $s2, 1 #next byte in image

			
save_color:
	addiu $s1, $s1, 1
	div $t3, $t3, $s0  #calculating srednia_wazona/suma_wartosci_kernela
		
	#OVERFLOW
		ble $t3, 255, not_overflow
		li $t3, 255
		sb $t3, -1($s1)
		j next_image_color
		
	not_overflow:
		bgez $t3, not_negative
		sb $zero, -1($s1)
		j next_image_color
		
	not_negative:
		sb $t3, -1($s1)
		j next_image_color
	

next_row:
	#li $v0, 32
	#li $a0, 1000
#	syscall

	
	addiu $s5, $s5, 1
	
	addiu $t7, $s3, 6 #two pixels plus row padding
	move $t5, $zero
	next_row_loop:
		beq $t5, $t7, next_image_row #save next two pixels (6 bytes + 1 byte 0?)
		lbu $t6, 0($s2) 
		sb $t6, 0($s1)
	
		addiu $s2, $s2, 1
		addiu $s1, $s1, 1	
		addiu $t5, $t5, 1
	j next_row_loop
	
save_row: #arguments $a0 - source buffer adress, $a1, destination buffer adress
	li $v0, 32
	li $a0, 1000
	syscall
	
	srl $t0, $s4, 2 #words in row
	move $t7, $zero
	
	save_row_loop:	
		lw $t6, 0($a2)#CHANGEEEE 
		sw $t6, 0($a1)
	
		addiu $a2, $a2, 4
		addiu $a1, $a1, 4	
		addiu $t7, $t7, 1
	bltu $t7, $t0, save_row_loop
	
return: jr $ra


save_result:
	subiu $a2, $s2, 3 #change to a0 !!!!
	subiu $a1, $s1, 3
	jal save_row

	li   $v0, 15 	#write to file filtered image
	lw   $a0, 4($sp)
	la   $a1, output_buffer
	lw   $a2, 16($sp)
	syscall
	
	j exit

exit: 
	lw $a0, 4($sp)	#close output file
	li $v0, 16
	syscall 
	
	li $v0, 10 		#exit
	syscall