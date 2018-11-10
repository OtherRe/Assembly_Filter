.data
input_dir: .asciiz "test5.bmp"
output_dir: .asciiz "test.txt"
prompt: .asciiz "\n Starting filtering"
prompt_end: .asciiz "\n End filtering\n"

		.align 2
buffer: .space 20000

.text
main:
#	j open_files
	
open_files:
	
	li $t0, 2
	la $t1, buffer
	sw $t0, 0($t1)
	sw $t0, 4($t1)
	
	li $v0, 13			#open file
	la $a0, output_dir 
	li $a1, 1
	syscall
	move $t0, $v0
	
	move $a0, $t0
	li   $v0, 15 	#write to file filtered block
	la   $a1, buffer
	li   $a2, 8
	syscall
	
		move $a0, $t0
	li   $v0, 15 	#write to file filtered block
	la   $a1, buffer
	li   $a2, 8
	syscall
		
		move $a0, $t0
	li   $v0, 15 	#write to file filtered block
	la   $a1, buffer
	li   $a2, 8
	syscall
	
		
		move $a0, $t0
	li   $v0, 15 	#write to file filtered block
	la   $a1, buffer
	li   $a2, 8
	syscall
	
			move $a0, $t0
	li   $v0, 15 	#write to file filtered block
	la   $a1, buffer
	li   $a2, 8
	syscall
	
		li $v0, 10 		#exit
	syscall




