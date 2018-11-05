.data
input_dir: .asciiz "test2.bmp"
output_dir: .asciiz "test_result.bmp"
prompt: .asciiz "\n Starting filtering"

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
	lw $s3, 4($s1) # width
	lw $s7, 20($s1) # size of an image

		
read_image:
	li   $v0, 14		#read imgage
	move $a0, $s0		#decsriptor
	move $a1, $s1   	#buffer	
	move $a2, $s7		#size of image

	syscall
	
	move $a0, $s0	    #close input file
	li $v0, 16
	syscall

prepare_kernel:
	la $s4, kernel
	
	li $t0, 0x01010101
	li $t1, 1
	
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
loop:	beq $t0, 9  start_filtering
		lb $t2, 0($t1)
		addu $s0, $s0, $t2
		addiu $t1, $t1, 1
		addiu $t0, $t0, 1
		j loop
	

	
start_filtering:
	li $v0, 4
	la $a0, prompt
	syscall
	#$s2 -> height
	#$s3 -> width
	#$s1 -> buffer
	li $t0, 0 # ROW
	li $t2, 0 # COLOR BYTE
	
	addi $t8, $s2, -1 #NRows ignoring edges
	addi $t9, $s3, -1 #NColumns ignoring edges
	
	li $t5, 4
	div $s3, $t5
	mfhi $s2 #<---- padding for each row
	
	mulu $s6, $s3, 3 # whole row of pixels
	addu $s6, $s6, $s2
	
	move $a0, $s1	 #first input pixel adress	
	la $s1, output_buffer
	
	
	
	jal save_row
	j next_row
	
outer_loop:
		li $t1, 0 # COLUMN
		bgeu $t0, $t8, save_result
inner_loop:	
			addiu $t1, $t1, 1 #next column
			bgeu $t1, $t9, next_row
			move $t2, $zero

pixel_color:
			beq $t2, 3, inner_loop #need to caltulate pixels for all three bytes of pixel
			li $t3, 0 #accumulator of suma ważona
			
			
			
			#left column
			li $a1, 0	#kernel tile
			li $a2, -3  #left column
			jal calculate_coef

			#middle column
			li $a1, 1	#kernel tile
			li $a2, 0  #middle column
			jal calculate_coef
			
			#right column
			li $a1, 2	#kernel tile
			li $a2, 3  #right column
			jal calculate_coef
			
			
			addiu $t2, $t2, 1 #next color byte
			addiu $a0, $a0, 1 #next byte in image
			j save_pixel

next_row:
	addiu $t0, $t0, 1
	
	addiu $t7, $s2, 6 #two pixels plus row padding
	move $t5, $zero
	next_row_loop:
		beq $t5, $t7, outer_loop #save next two pixels (6 bytes + 1 byte 0?)
		lbu $t6, 0($a0) 
		sb $t6, 0($s1)
	
		addiu $a0, $a0, 1
		addiu $s1, $s1, 1	
		addiu $t5, $t5, 1
	j next_row_loop
	
save_row:

	
	mulu $t5, $t9, 3
	move $t7, $zero
	
	save_row_loop:	
		bgeu $t7, $t5  return #save next row of pixels
		lb $t6, 0($a0) 
		sb $t6, 0($s1)
	
		addiu $a0, $a0, 1
		addiu $s1, $s1, 1	
		addiu $t7, $t7, 1
	j save_row_loop
	
return: jr $ra

save_pixel:
	addiu $s1, $s1, 1
	div $t3, $t3, $s0  #calculating srednia_wazona/suma_wartosci_kernela
		
	#OVERFLOW
		ble $t3, 255, not_overflow
		li $t3, 255
		sb $t3, -1($s1)
		j pixel_color
		
	not_overflow:
		bgez $t3, not_negative
		sb $zero, -1($s1)
		j pixel_color
		
	not_negative:
		sb $t3, -1($s1)
		j pixel_color
	
	
calculate_coef:
			#calculating index of current pixel
	addu $t5, $a0, $a2  #left or right pixel
	subu $t5, $t5, $s6  #lower row first
	addu $a1, $a1, $s4	#kernel adress
			
	lbu $t6, 0($t5)     #value of lower pixel
	lb $t7, 0($a1)		#value of kernel tile
			
	mul $t6, $t6, $t7	#calculate cooeficient
	add $t3, $t3, $t6	#add cooeficient into accumulator		
			
	add $t5, $t5, $s6			
			
	lbu $t6, 0($t5)     #value of middle pixel
	lb $t7, 3($a1)		#value of kernel tile
			
	mul $t6, $t6, $t7	#calculate cooeficient
	add $t3, $t3, $t6	#add cooeficient into accumulator
			
	addu $t5, $t5, $s6
			
	lbu $t6, 0($t5)     #value of upper pixel
	lb $t7, 6($a1)		#value of kernel tile
			
	mul $t6, $t6, $t7	#calculate cooeficient
	add $t3, $t3, $t6	#add cooeficient into accumulator

						
	jr $ra

save_result:
	jal save_row

	li   $v0, 15 	#write to file filtered image
	move $a0, $s5
	la   $a1, output_buffer
	move $a2, $s7
	syscall
	
	j exit

exit: 
	move $a0, $s5	#close output file
	li $v0, 16
	syscall 
	
	li $v0, 10 		#exit
	syscall
