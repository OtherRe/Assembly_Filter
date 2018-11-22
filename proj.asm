.data
input_dir: .asciiz "test6.bmp"
input_dir_buffer: .space 50
output_dir_buffer: .space 50
output_dir: .asciiz "test_result.bmp"
prompt: .asciiz "\n Starting filtering"
prompt_end: .asciiz "\n End filtering\n"
prompt_kernel: .asciiz "\nGive value of kernel nr #: "
prompt_input_path: .asciiz "\n Please give an input path\n"
prompt_output_path: .asciiz "\n Please give an output path\n"

		.align 2
buffer: .space 10000

		.align 2
output_buffer: .space 10000

kernel:
		.align 2
		.space 9		


.text
main:
read_input_path:
	li $v0, 4
	la $a0, prompt_input_path
	syscall
	
	li $v0, 8
	la $a0, input_dir_buffer
	li $a1, 40
	syscall
	
	li $t0, 0
	la $t1, input_dir_buffer
delete_end_loop:
	bge $t0, 40, open_files
	lbu $t2, 0($t1)
	addiu $t0, $t0, 1
	addiu $t1, $t1, 1
	bgeu $t2, ' ', delete_end_loop
	sb $zero, -1($t1) 

read_output_path:
	li $v0, 4
	la $a0, prompt_output_path
	syscall
	
	li $v0, 8
	la $a0, output_dir_buffer
	li $a1, 40
	syscall
	
	li $t0, 0
	la $t1, output_dir_buffer
	
delete_end_loop_output:
	bge $t0, 40, open_files
	lbu $t2, 0($t1)
	addiu $t0, $t0, 1
	addiu $t1, $t1, 1
	bgeu $t2, ' ', delete_end_loop_output
	sb $zero, -1($t1) 	
	
open_files:
	li $v0, 13		  #open file
	la $a0, input_dir_buffer 
	li $a1, 0
	syscall

	move $s0, $v0	#save file descriptor

	bltz $s0, exit  #couldn't open a file
	
	li $v0, 13			#open file
	la $a0, output_dir_buffer 
	li $a1, 9
	syscall

	move $s5, $v0	#save file descriptor
	
	subiu $sp, $sp, 28
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
	la $t4, prompt_kernel
	addiu $t4, $t4, 25
	li $t3, 1
read_kernel_loop:
	addu $t5, $t3, '0'
	sb $t5, 0($t4)
	li $v0, 4
	la $a0, prompt_kernel
	syscall
	
	li $v0, 5
	syscall
	sb $v0, 0($s4)
	
	addiu $s4, $s4, 1
	addiu $t3, $t3, 1
	blt   $t3, 10, read_kernel_loop
	
	
	li $s0, 0 #sum of all kernel values accumulator
	la $t1, kernel #kernell adress
	
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

prepare_block_info:
	li $t0, 10000      # max block size
	
	lw $t1, 12($sp)    #width
	addiu $t1, $t1, 1  #some more room for padding
	mulu $t1, $t1, 3   #width in bytes
	divu $t0, $t1
	
	mflo $t2 # max rows per block
	
	lw $t1, 8($sp) #rows
	subiu $t4, $t2, 2 #block without up and down borders
	
	divu $t1, $t4
	mfhi $t3 #remainder of rows
	bgtz $t3, j_1 #remainder shouldn't be zero
	move $t3, $t4 	
j_1:
	sw $t3, 20($sp)

	
prepare_filter:
	li $v0, 4
	la $a0, prompt
	syscall

	la $s1, output_buffer
	la $s2, buffer
	
	lw $t8, 8($sp) #rows
	lw $t9, 12($sp)#columns

	andi $s3, $t9, 3 #<---- padding of zeros for each row
			
	mulu $s4, $t9, 3 # whole row of pixels in bytes
	addu $s4, $s4, $s3 #plus padding
		
	li $s5, 0 # ROW counter
	li $s6, 0 # COLUMN counter
	
	addi $t8, $t8, -1 #NRows upper edge
	addi $t9, $t9, -2 #NColumns ignoring edges
	mulu $t9, $t9, 3
	
	subiu $t3, $t2, 2
	mulu  $t3, $t3, $s4
	sw    $t3, 24($sp)
	
	li $t1, 0
	#t1 -> row counter in current block
	#t2 -> rows per block
	
	#s0 -> kernel sum
	#s1 -> output pointer
	#s2 -> input pointer
	#s3 -> padding for each row
	#s4 -> whole row in bytes
	#s5 -> row counter
	#s6 -> column counter
	#s7 -> number of blocks
	
read_first_block:
	la $a1, buffer
	addu $a2, $a1, $s4
	jal save_whole_row

	li   $v0, 14		#read imgage
	lw   $a0, 0($sp)	#decsriptor
	subiu $a2, $t2, 1
	mulu $a2, $s4, $a2	#size of a block
	syscall	

start_filtering:
	addu  $s2, $s2, $s4 #moving pointers
	addiu $s2, $s2, 3
	addiu $s1, $s1, 3
	li 	  $s5, 0
	li    $t1, 2
	
save_left_edge:
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
	addiu $s5, $s5, 1  #next overall row
	
	addiu $t7, $s3, 6 #two pixels plus row padding
	move $t5, $zero
	next_row_loop:	
		lbu $t6, 0($s2) 
		sb $t6, 0($s1)
	
		addiu $s2, $s2, 1
		addiu $s1, $s1, 1	
		addiu $t5, $t5, 1
	blt $t5, $t7, next_row_loop #save next two pixels (6 bytes + 1 byte 0?)
	
	addiu $t1, $t1, 1  #next row in current block
	bltu $t1, $t2, next_image_row#
	li $t1, 2
	
save_block:
	subiu $a2, $s2, 3 #change to a0 !!!! #move rows to bottom
	subu $a2, $a2, $s4
	la $a1, buffer
	jal save_whole_row
	jal save_whole_row
	
	li   $v0, 14		#read imgage	#load next block
	lw   $a0, 0($sp)	#decsriptor
	lw   $a2, 24($sp)
	syscall
	
	la $s2, buffer		 #move input pointer to correct place
	addu  $s2, $s2, $s4
	addiu $s2, $s2, 3
	

	li   $v0, 15 	#write to file filtered block
	lw   $a0, 4($sp)
	la   $a1, output_buffer
	syscall
	
	la $s1, output_buffer
	addiu $s1, $s1, 3
	j save_left_edge
	
	
save_whole_row: #arguments $a2 - source buffer adress, $a1, destination buffer adress
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
	jal save_whole_row

	li   $v0, 15 	#write to file filtered image
	lw   $a0, 4($sp)
	la   $a1, output_buffer
	lw   $a2, 20($sp)
	mulu $a2, $a2, $s4
	syscall
	
	j exit

exit: 
	lw $a0, 4($sp)	#close output file
	li $v0, 16
	syscall 
	
	lw $a0, 0($sp)	#close input file
	li $v0, 16
	syscall
	
	addiu $sp, $sp 24
	
	li $v0, 10 		#exit
	syscall
