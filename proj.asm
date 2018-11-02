.data
input_dir: .asciiz "test1.bmp" 
output_dir: .asciiz "test_result.bmp"
prompt: .asciiz "\n Couldnt open a file"

		.align 2
buffer: .space 200000

		.align 2
output_buffer: .space 200000

kernel:
		.align 2
		.space 9		


.text
main:
	jal open_files
	jal read_and_save_image_info
	#jal read_image
	#jal prepare_kernel		
	#jal start_filtering

	j exit
	
	

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
	
	li $v0, 11
	lb $a0, 0($s1)
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

	
	jr $ra
		
read_image:
	li   $v0, 14		#read imgage
	move $a0, $s0		#decsriptor
	move $a1, $s1   	#buffer	
	move $a2, $s7		#size of image

	syscall
	
	move $a0, $s0	    #close input file
	li $v0, 16
	syscall

	jr $ra
	

prepare_kernel:
	la $s4, kernel
	
	li $t0, 0x01010101
	li $t1, 1

	sw $t0, 0($s4)	#simple uśredniajacy filtr all 1's
	sw $t0, 4($s4)
	sb $t1, 8($s4)
	
	li $s0, 0 #sum of all kernel values accumulator
	li $t0, 9 #counter
	move $t1, $s4
loop:	beqz $t0, return
		lb $t2, 0($t1)
		addu $s0, $s0, $t2
		addiu $t1, $t1, 1
		subiu $t0, $t0, 1
		j loop
return:	jr $ra
	
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
	jr $ra
	
start_filtering:
	#$s2 -> height
	#$s3 -> width
	#$s1 -> buffer
	li $t0, 1 # ROW
	li $t1, 1 # COLUMN
	li $t2, 0 # COLOR BYTE
	mulu $s6, $s3, 3 # whole row of pixels
	move $a0, $s1	 #first input pixel adress	
	la $s1, output_buffer
	
	subiu $t8, $s2, 1 #for now ignoring edges
	subiu $t9, $s3, 1	
	
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
	
	li $t5 , 6
a:	beqz $t5, outer_loop #save next two pixels (6 bytes)
	lbu $t6, 0($a0) 
	sb $t6, 0($s1)
	
	addiu $a0, $a0, 1
	addiu $s1, $s1, 1	
	subiu $t5, $t5, 1
	j a
	
save_row:

	move $t5 , $t9
b:	beqz $t5, return #save next two pixels (6 bytes)
	lbu $t6, 0($a0) 
	sb $t6, 0($s1)
	
	addiu $a0, $a0, 1
	addiu $s1, $s1, 1	
	subiu $t5, $t5, 1
	j b
	
	
save_pixel:
	divu $t3, $t3, $s0  #calculating srednia_wazona/suma_wartosci_kernela
	sb $t3, 0($s1)
	addiu $s1, $s1, 1
	
	j pixel_color
	
	
calculate_coef:
			#calculating index of current pixel
			addu $t5, $a0, $a2  #left or right pixel
			subu $t5, $t5, $s6  #lower row first
			addu $a1, $a1, $s4	#kernel adress
			
			lbu $t6, 0($t5)     #value of lower pixel
			lbu $t7, 0($a1)		#value of kernel tile
			
			mul $t6, $t6, $t7	#calculate cooeficient
			add $t3, $t3, $t6	#add cooeficient into accumulator		
			
			addu $t5, $t5, $s6			
			
			lbu $t6, 0($t5)     #value of middle pixel
			lbu $t7, 3($a1)		#value of kernel tile
			
			mul $t6, $t6, $t7	#calculate cooeficient
			add $t3, $t3, $t6	#add cooeficient into accumulator
			
			addu $t5, $t5, $s6
			
			lbu $t6, 0($t5)     #value of upper pixel
			lbu $t7, 6($a1)		#value of kernel tile
			
			mul $t6, $t6, $t7	#calculate cooeficient
			add $t3, $t3, $t6	#add cooeficient into accumulator

						
			jr $ra

save_result:
	li $v0, 15 	#write to file filtered image
	move $a0, $s5
	la $a1, output_buffer
	move $a2, $s7
	syscall
	
	move $a0, $v0
	li $v0, 1
	syscall
	
	j exit

exit: 
	move $a0, $s5	#close output file
	li $v0, 16
	syscall 
	
	li $v0, 10 		#exit
	syscall
