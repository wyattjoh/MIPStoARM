#-------------------------------
# Student MIPStoARM Testing file
# Author: Taylor Lloyd
# Date: July 4, 2012
#
#-------------------------------

.data
	.align 2
binary:
	.space 2052
noFileStr:
	.asciiz "Couldn't open specified file.\n"
.text
main:
	lw	$a0 4($a1)	# Put the filename pointer into $a0
	li	$a1 0		# Read Only
	li	$a2 0		# No Mode Specified
	li	$v0 13		# Open File
	syscall
	bltz	$v0 main_err	# Negative means open failed

	move	$a0 $v0		#point at open file
	la	$a1 binary	# write into my binary space
	li	$a2 2048	# read a file of at max 2kb
	li	$v0 14		# Read File Syscall
	syscall
	la	$t0 binary
	add	$t0 $t0 $v0	#point to end of binary space

	li	$t1 0xFFFFFFFF	#Place ending sentinel
	sw	$t1 0($t0)

	la	$a0 binary	#prepare pointer for assignment
	jal	MIPStoARM

	sll	$v0 $v0 2	# instructions are words (*4)
	add	$s0 $v0 $v1	# $s0 = last instruction

	main_parseLoop:
		beq	$v1 $s0 main_doneParse	# If we're done, jump to complete
		lw	$a0 0($v1)		# Load the word to parse

		addi	$sp $sp -8
		sw	$s0 4($sp)
		sw	$v1 0($sp)

		jal	parseARM

		lw	$s0 4($sp)
		lw	$v1 0($sp)
		addi	$sp $sp 8

		addi	$v1 $v1 4

		j	main_parseLoop

	main_doneParse:
		j	main_done
	main_err:
		la	$a0 noFileStr
		li	$v0 4
		syscall
	main_done:
		li	$v0 10
		syscall
.data
	andStr: .asciiz "AND"
	orStr: .asciiz "OR"
	addStr: .asciiz "ADD"
	subStr: .asciiz "SUB"
	movStr: .asciiz "MOV"
	cmpStr: .asciiz "CMP"
	bxStr: .asciiz "BX"
	bStr: .asciiz "B"
	balStr: .asciiz "BAL"
	unkStr: .asciiz "???"

	eqStr: .asciiz "EQ "
	geStr: .asciiz "GE "
	gtStr: .asciiz "GT "
	blankStr: .asciiz " "
	rStr: .asciiz "R"
	sStr: .asciiz "S "

	arStr: .asciiz " AR "
	lrStr: .asciiz " LR "
	llStr: .asciiz " LL "
	rorStr: .asciiz " ROR "
	
	sepStr: .asciiz ", "
	nlStr: .asciiz "\n"

.text

#-----------
# parseARM
#
# ARGS: a0=ARM instruction
#
# t8 = (0=data processing)/(1=branch)/(2=bx)
# s0 = instruction
#
#-----------
parseARM:
	move	$s0 $a0

	#ID Branches
	li	$t8 2

	sll	$t0 $a0 4
	srl	$t0 $t0 28

	#B
	la	$t9 bStr
	li	$t1 0x0A
	beq	$t0 $t1 parseARM_pOp
	
	#BAL
	la	$t9 balStr
	li	$t1 0x0A
	beq	$t0 $t1 parseARM_pOp

	#Isolate and identify DataProc OpCodes
	sll	$t0 $a0 7
	srl	$t0 $t0 28	#Isolate opCode

	li	$t8 0
	
	#AND
	la	$t9 andStr
	li	$t1 0x00
	beq	$t0 $t1 parseARM_pOp
	
	#OR
	la	$t9 orStr
	li	$t1 0x0C
	beq	$t0 $t1 parseARM_pOp

	#ADD
	la	$t9 addStr
	li	$t1 0x04
	beq	$t0 $t1 parseARM_pOp

	#SUB
	la	$t9 subStr
	li	$t1 0x02
	beq	$t0 $t1 parseARM_pOp

	#MOV
	la	$t9 movStr
	li	$t1 0x0D
	beq	$t0 $t1 parseARM_pOp

	#CMP
	la	$t9 cmpStr
	li	$t1 0x0A
	beq	$t0 $t1 parseARM_pOp

	li	$t8 1

	#BX
	la	$t9 bxStr
	li	$t1 0x09
	beq	$t0 $t1 parseARM_pOp

	li	$t8 0
	la	$t9 unkStr

	parseARM_pOp:
		move	$a0 $t9
		li	$v0 4
		syscall

# ID the condition
	srl	$t0 $s0 28

	#Always
	la	$t9 blankStr
	li	$t1 0x0E
	beq	$t0 $t1 parseARM_pCond

	#Equals
	la	$t9 eqStr
	li	$t1 0x00
	beq	$t0 $t1 parseARM_pCond

	#GreaterThan
	la	$t9 gtStr
	li	$t1 0x0C
	beq	$t0 $t1 parseARM_pCond

	#GreaterThan
	la	$t9 geStr
	li	$t1 0x0A
	beq	$t0 $t1 parseARM_pCond

	la	$t9 unkStr

	parseARM_pCond:
		move	$a0 $t9
		li	$v0 4
		syscall
	
	beqz	$t8 parseARM_DataProc
	li	$t0 2
	beq	$t8 $t0 parseARM_Branch
	j	parseARM_BX

parseARM_DataProc:
	lui	$t0 0x0010
	and	$t0 $t0 $s0	#mask out sign bit
	beqz	$t0 padp_noStat
	
	la	$a0 sStr
	li	$v0 4
	syscall	
	
	padp_noStat:

	#If CMP, don't print Dest
	sll	$t0 $s0 7
	srl	$t0 $t0 28
	li	$t1 0x0A
	beq	$t0 $t1 padp_noDest
	#Otherwise go ahead

	sll	$t0 $s0 16
	srl	$t0 $t0 28	#isolate Destination
	
	la	$a0 rStr
	li	$v0 4
	syscall

	move	$a0 $t0
	li	$v0 1
	syscall			#print register

	la	$a0 sepStr
	li	$v0 4
	syscall			#space for next
	
	padp_noDest:

	#If MOV, don't print Operand 1
	sll	$t0 $s0 7
	srl	$t0 $t0 28
	li	$t1 0x0D
	beq	$t0 $t1 padp_noOp1
	#Otherwise go ahead

	sll	$t0 $s0 12
	srl	$t0 $t0 28	#isolate operand 1
	
	la	$a0 rStr
	li	$v0 4
	syscall

	move	$a0 $t0
	li	$v0 1
	syscall			#print register

	la	$a0 sepStr
	li	$v0 4
	syscall			#space for next

	padp_noOp1:
	lui	$t0 0x0200	#mask out immediate indicator
	and	$t0 $t0 $s0
	
	bnez	$t0 padp_imm
	j	padp_reg


	padp_imm:
		andi	$t0 $s0 0x00FF	#immediate value
		srl	$t1 $s0 8	
		andi	$t1 $t1 0x0F	#Rotation value
		sll	$t1 $t1 1	#double it
		
		ror	$a0 $t0 $t1
		li	$v0 1
		syscall
		j	parseARM_done

	padp_reg:
		andi	$t0 $s0 0x0F	#mask out last register
		la	$a0 rStr
		li	$v0 4
		syscall

		move	$a0 $t0
		li	$v0 1
		syscall			#print register
		
		sll	$t0 $s0 25	#isolate shift type
		srl	$t0 $t0 30

		li	$t1 0x00	#logical left
		la	$a0 llStr
		beq	$t0 $t1 padp_shift

		li	$t1 0x01	#logical right
		la	$a0 lrStr
		beq	$t0 $t1 padp_shift

		li	$t1 0x02	#arithmetic right
		la	$a0 arStr
		beq	$t0 $t1 padp_shift

		li	$t1 0x03	#rotate right
		la	$a0 rorStr
		beq	$t0 $t1 padp_shift

		la	$a0 unkStr	

	padp_shift:
		#Don't print if we're shifting 0
		andi	$t0 $s0 0x0010	#isolate reg/imm
		bnez	$t0 padp_pShift	#always print if register
		sll	$t0 $s0 20	#isolate shift amount
		srl	$t0 $t0 27
		beqz	$t0 parseARM_done

	padp_pShift:
		#Now we definitely want to print
		li	$v0 4		#print rotation type
		syscall

		andi	$t0 $s0 0x0010	#isolate reg/imm
		bnez	$t0 padp_shiftReg

	padp_shiftVal:
		sll	$t0 $s0 20	#isolate shift amount
		srl	$a0 $t0 27

		li	$v0 1
		syscall

		j	parseARM_done

	padp_shiftReg:
		la	$a0 rStr
		li	$v0 4
		syscall			#print register 'R'

		sll	$t0 $s0 20	#isolate shift register
		srl	$a0 $t0 28

		li	$v0 1
		syscall			#print register value

		j	parseARM_done

parseARM_Branch:
	li	$t0 0x00FFFFFF		#mask lower 24 bits
	and	$t0 $t0 $s0		#branch offset

	sll	$t0 $t0 8
	sra	$a0 $t0 6		#sign extend, *4

	li	$v0 1
	syscall				#print the branch offset

	j	parseARM_done
parseARM_BX:
	la	$a0 rStr
	li	$v0 4
	syscall			#print register 'R'

	andi	$a0 $s0 0x0F	#isolate the register
	li	$v0 1
	syscall

	j	parseARM_done
parseARM_done:
	la	$a0 nlStr
	li	$v0 4
	syscall

	jr	$ra

######################### Student Code Begins Here #########################


#	 `7MMM.     ,MMF'`7MMF'`7MM"""Mq.  .M"""bgd      mm                   db      `7MM"""Mq.  `7MMM.     ,MMF'
#	   MMMb    dPMM    MM    MM   `MM.,MI    "Y      MM                  ;MM:       MM   `MM.   MMMb    dPMM  
#	   M YM   ,M MM    MM    MM   ,M9 `MMb.        mmMMmm ,pW"Wq.       ,V^MM.      MM   ,M9    M YM   ,M MM  
#	   M  Mb  M' MM    MM    MMmmdM9    `YMMNq.      MM  6W'   `Wb     ,M  `MM      MMmmdM9     M  Mb  M' MM  
#	   M  YM.P'  MM    MM    MM       .     `MM      MM  8M     M8     AbmmmqMA     MM  YM.     M  YM.P'  MM  
#	   M  `YM'   MM    MM    MM       Mb     dM      MM  YA.   ,A9    A'     VML    MM   `Mb.   M  `YM'   MM  
#	 .JML. `'  .JMML..JMML..JMML.     P"Ybmmd"       `Mbmo`Ybmd9'   .AMA.   .AMMA..JMML. .JMM..JML. `'  .JMML.
#
#	Arguments:
#		$a0 = pointer to memory containing a MIPS function. The function ends when the sentinel word 0xFFFFFFFF is encountered.
#	Return Values:
#		$v0 = The number of ARM instructions generated.
#		$v1 - A pointer to the first instruction of the ARM program that is stored in a memory space that you are responsible to allocate (either in pre-allocated space, or allocated at runtime using the sbrk syscall)

.data

rsData: .word 0x0
rtData: .word 0x0
rdData: .word 0x0
shamtData: .word 0x0
addressData: .word 0x0

rotateData: .word 0x0
immData: .word 0x0

armAddress: .word 0x0
armCount: .word 0x0

branchTree: .word 0x0

.text


#
#  allocateARMword
#  -------------------------
#
#  This function allocate the number of words passed to it, as well as storing the address into armAddress
#
#  $a0 => Number of ARM instructions to allocate for (1 per word)
#

allocateARMword:
	#  Prepare the stack
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -16
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $a0, -12($fp)
	sw $v0, -16($fp)
	
	#  1 byte is 8 bits
	#  1 word is 4 bytes
	#  1 inst is 1 word
	#  sbrk allocates $a0 bytes, address of the start returned at $v0
	
	#  Determine the amount of bytes to allocate from the number of instructions recieved
	li $t0, 0x4
	mult $a0, $t0
	
	#  Perform the allocation using sbrk
	mflo $a0
	li $v0, 9
	syscall
	
	#  Restore the value for the number of instructions
	lw $a0, -12($fp)
	sw $v0, armAddress
	
	#  Zero the data segment
	li $t0, 0x1
	zeroLoop:
		beq $t0, $a0, EndzeroLoop #  Am I at the end of the data segment?
		sw $0, 0($v0)  #  Store a zero into the word
		addi $v0, $v0, 4 #  Increment the address we are storing zeros to
		addi $t0, $t0, 0x1 #  Increment the counter of the segment we are on
		j zeroLoop #  Loop
	EndzeroLoop:
	
	#  Restore values
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	lw $v0, -16($fp)
	#  Unwind the stack
	addi $sp, $sp, 20
	lw $fp, -4($sp)	
	jr $ra


#
#	computeRotate
#	-----------------------
#
#	Based on an input of the address for the immediate field that we are converting into a rotated field, 
#
#
#	$a0 => address to immediate value to have the rotation computed
#
#	$v0 <= value of the rotation
#	$v1 <= value into the immediate field
#

computeRotate:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -36
	#  Store the values
	sw $ra, -4($fp)
	sw $a0, -8($fp)
	sw $t0, -12($fp)
	sw $t1, -16($fp)
	sw $t2, -20($fp)
	sw $t3, -24($fp)
	sw $t4, -28($fp)
	sw $t5, -32($fp)
	sw $t6, -36($fp)
	
	#  Calculate the distance from the most signifigant bit and least signifigant bit
	lw $t0, 0($a0)
	
	beqz $t0, crZero
	
	li $t1, 0x1
	
	crCountLength:
		#  Check if first bit is one, else add a 1 to the counter and shift the value to the right by one
		andi $t2, $t0, 0x1
		bnez $t2, crCountLengthEnd
		addi $t1, $t1, 0x1
		srl $t0, $t0, 1
		j crCountLength
	crCountLengthEnd:
	#  $t1 <= Position of the first (1)
	
	lw $t0, 0($a0)
	
	li $t2, 0x1
	crCountLength2:
		srl $t0, $t0, 1
		beqz $t0, crCountLengthEnd2
		addi $t2, $t2, 1
		j crCountLength2
	crCountLengthEnd2:
	#  $t2 <= Position of the last (1)
	
	#  $t3 <= Position of the last element (1) in the value
	sub $t3, $t2, $t1
	addi $t3, $t3, 1
	lw $t0, 0($a0)
	
	# sltiu $t4, $t1, 9
	# bne $t4, $0, crLess
	
	crMore:
		li $t4, 8
		ble $t2, $t4, crmImm
		
		crmMore:
			li $t4, 0
			crmL1:
				beqz $t0, crmL1E
				addi $t4, $t4, 1
				sll $t0, $t0, 2
				j crmL1
			crmL1E:
			
			li $t5, 2
			mult $t5, $t4
			mflo $t5
			
			li $t6, 32
			sub $t5, $t6, $t5
			
			lw $t0, 0($a0)
			srlv $v1, $t0, $t5
			
			move $v0, $t4
			
			j crDone
		crmImm:
			li $v0, 0x0
			move $v1, $t0
		
			j crDone
	
	crZero:
		li $v0, 0x0
		li $v1, 0x0
		
		j crDone
	
	crDone:
	
	lw $ra, -4($fp)
	lw $a0, -8($fp)
	lw $t0, -12($fp)
	lw $t1, -16($fp)
	lw $t2, -20($fp)
	lw $t3, -24($fp)
	lw $t4, -28($fp)
	lw $t5, -32($fp)
	lw $t6, -36($fp)
	#  Unwind the stack
	addi $sp, $sp, 40
	lw $fp, -4($sp)
	jr $ra

#
#	convertMIPStoARMregister
#	----------------------
#	
#	Converts the value of a MIPS register into an ARM register code
#	
#	$a0 => location in memory to value of register number in MIPS
#	$v0 <= register number in ARM
#

convertMIPStoARMregister:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -12
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)

	#  Register Mappings:
	#
	#  MIPS : ARM
	#
	#  1 at: 1
	#  2 v0: 2
	#  3 v1: 3
	#  4 a0: 4
	#  5 a1: 5
	#  6 a2: 6
	#  7 a3: 7
	#  8 t0: 8
	#  9 t1: 9
	#  10 t2: 10
	#  11 t3: 11
	#  12 t4: 12
	#  29 sp: 13
	#  31 ra: 14
	
	lw $t0, 0($a0)
	
	slti $t1, $t0, 13
	bne $t1, $0, cmtaDirect
	
	li $t1, 29
	beq $t1, $t0, cmta13
	
	li $t1, 31
	beq $t1, $t0, cmta14
	
	#  It does not match our table, mark it as invalid and exit
	li $v0, -1
	j DonecmtaDirect
	
	cmta13:
		li $v0, 13
		j DonecmtaDirect
	cmta14:
		li $v0, 14
		j DonecmtaDirect
	cmtaDirect:
		add $v0, $t0, $0
	DonecmtaDirect:
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	#  Unwind the stack
	addi $sp, $sp, 16
	lw $fp, -4($sp)	
	jr $ra

#
#	parseRType
#	----------------------
#	
#	All R type instructions have an op code of 0x0
#	
#	$a0 => address to mips instruction
#

parseRType:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -20
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)
	sw $t2, -16($fp)
	sw $a0, -20($fp)
	
	#  Load the address from memory
	lw $t0, 0($a0)
	
	#  Masking element
	li $t1, 0x1F
	
	srl $t0, $t0, 6
	and $t2, $t0, $t1
	
	sw $t2, shamtData
	
	srl $t0, $t0, 5
	and $t2, $t0, $t1
	
	sw $t2, rdData
	
	srl $t0, $t0, 5
	and $t2, $t0, $t1
	
	sw $t2, rtData
	
	srl $t0, $t0, 5
	and $t2, $t0, $t1
	
	sw $t2, rsData
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	lw $t2, -16($fp)
	lw $a0, -20($fp)
	#  Unwind the stack
	addi $sp, $sp, 24
	lw $fp, -4($sp)
	jr $ra

#
#	parseIType
#	----------------------
#	
#	
#	
#	$a0 => address to mips instruction
#
#	$v0 <= if success: 0, else: -1
#

parseIType:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -20
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)
	sw $t2, -16($fp)
	sw $a0, -20($fp)
	
	lw $t0, 0($a0)
	
	#  Masking element
	li $t1, 0xFF
	sll $t1, $t1, 8
	ori $t1, $t1, 0xFF
	
	and $t2, $t0, $t1
	
	sw $t2, addressData
	
	#  Determine the rotaion values and imm values
	
	# rotateData: .word 0x0
	# immData: .word 0x0
	
	#	computeRotate
	#	$a0 => address to immediate value to have the rotation computed
	#
	#	$v0 <= value of the rotation
	#	$v1 <= value into the immediate field
	#
	la $a0, addressData
	jal computeRotate
	
	sw $v0, rotateData
	sw $v1, immData
	
	#  Masking element
	li $t1, 0x1F
	
	srl $t0, $t0, 16
	and $t2, $t0, $t1
	
	sw $t2, rtData
	
	srl $t0, $t0, 5
	and $t2, $t0, $t1
	
	sw $t2, rsData
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	lw $t2, -16($fp)
	lw $a0, -20($fp)
	#  Unwind the stack
	addi $sp, $sp, 24
	lw $fp, -4($sp)
	jr $ra

#
#  rrOperation
#  ------------------------
#
#  $a0 => opCode of operation
#
#  Will read data from memory for the specific registers
#
#  $v0 <= ARM operation translated
	
rrOperation:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -12
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $a0, -12($fp)
	
	# li $t6, 0xE00 #  Begin translation
	sll $t0, $a0, 0x4
	
	#  Perform register translation
	
	la $a0, rsData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rroInvalid
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0x4
		
	la $a0, rdData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rroInvalid
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0xC
		
	la $a0, rtData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rroInvalid
	
	or $t0, $v0, $t0
	
	move $v0, $t0
	
	j rroExit
	
	rroInvalid:
		li $v0, -1
	rroExit:
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	#  Unwind the stack
	addi $sp, $sp, 16
	lw $fp, -4($sp)
	jr $ra

#
#  riOperation
#  ------------------------
#
#  $a0 => op code + condition code of operation
#
#  $v0 <= ARM operation translated

riOperation:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -12
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $a0, -12($fp)
	
	# li $t6, 0xE00 #  Begin translation
	sll $t0, $a0, 4
	
	la $a0, rsData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rioInvalid
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0x4
		
	la $a0, rtData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rioInvalid
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0x4
	
	lw $v0, rotateData
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0x8
	
	lw $v0, immData
	
	or $t0, $v0, $t0
	
	move $v0, $t0
	
	j rioExit
	
	rioInvalid:
		li $v0, -1
	rioExit:
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	#  Unwind the stack
	addi $sp, $sp, 16
	lw $fp, -4($sp)
	jr $ra

#
#  jumpOperation
#  ------------------------
#
#  $a0 => condition code of jump
#s
#  Will read data from memory for the specific registers
#
#  $v0 <= ARM operation translated

jumpOperation:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -12
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $a0, -12($fp)
	
	#  Shift condition to the left by 28 bits
	sll $t0, $a0, 28
	
	li $t1, 0x12F
	sll $t1, $t1, 16
	
	or $t0, $t0, $t1
	
	li $t1, 0xFF1
	sll $t1, $t1, 4
	
	or $t0, $t0, $t1
	
	la $a0, rsData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, joInvalid
	
	or $v0, $t0, $v0
	
	j joExit
	
	joInvalid:
		li $v0, -1
	joExit:
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	#  Unwind the stack
	addi $sp, $sp, 16
	lw $fp, -4($sp)
	jr $ra

#
#  computeOffset
#
#  computes the offset of a branch
#
#  $a0 => current instruction (0 indexed)
#  $a1 => relative to current (+/-)

computeOffset:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -24
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)
	sw $t2, -16($fp)
	sw $t3, -20($fp)
	sw $t4, -24($fp)
	
	la $t0, branchTree
	add $t0, $t0, $a0
	addi $t0, $t0, 1
	
	li $t2, 0x0 #  Our val variable
	
	beq $a1, $0, cpZero
	
	li $t1, 0x4
	div $a1, $t1
	
	mfhi $t1
	
	bnez $t1, cpErr
	
	mflo $t1 #  Our Index variable
	
	bgtz $a1, cpPos
	
	cpNeg:
		beqz $t1, cpExit
		
		add $t3, $t0, $t2
		lb $t3, 0($t3)
		
		addi $t2, $t2, -1
		
		li $t4, 2
		beq $t4, $t3, cpNeg
		
		addi $t1, $t1, 1
		
		j cpNeg
	cpPos:
		beqz $t1, cpExit
			
		add $t3, $t0, $t2
		lb $t3, 0($t3)
			
		addi $t2, $t2, 1
			
		li $t4, 1
		beq $t4, $t3, cpPos
			
		addi $t1, $t1, -1
			
		j cpPos
	cpZero:
	cpErr:
	cpExit:
		
	li $t1, 0x4
	mult $t2, $t1
	
	mflo $v0
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	lw $t2, -16($fp)
	lw $t3, -20($fp)
	lw $t4, -24($fp)
	#  Unwind the stack
	addi $sp, $sp, 28
	lw $fp, -4($sp)
	jr $ra

#  
#  processOffset
#  ---------------------
#  
#  $a1 <= offset address to be processed
#  $a0 <= current inst offset
#  $v0 => new offset

processOffset:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -4
	#  Store the values
	sw $ra, -4($fp)
	
	lw $a1, 0($a1)
	
	sll $a1, $a1, 16
	sra $a1, $a1, 14
	
	# addi $a0, $a0, 1
	
	jal computeOffset
	
	sll $v0, $v0, 6
	srl $v0, $v0, 8
	
	lw $ra, -4($fp)
	#  Unwind the stack
	addi $sp, $sp, 8
	lw $fp, -4($sp)
	jr $ra

# 
# countInstructions
# 
#  counts the number of MIPS instructions and additionally computes the amount of instructions that will be needed for branch instructions. The secondary purpose of this is to generate the seconday table that is used to store information about the relative index of a said instruction to another branch style instrucion to be used in the processOffset method.
#
#  $a0 => address of first instruction
#  $v0 <= number of corrasponding ARM instructions
# 

countInstructions:
	#  Prepare the stack
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -32
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)
	sw $t2, -16($fp)
	sw $t3, -20($fp)
	sw $a0, -24($fp)
	sw $t4, -28($fp)
	sw $t5, -32($fp)
	
	li $t0, 0x0 #  The counter for the number of instructions
	li $t1, -1 #  The ending character
	ciLoop:
		lw $t2, 0($a0) #  Load the instruction
		beq $t2, $t1, DciLoop #  Check if it is equal to the ending character
		addi $t0, $t0, 0x1 #  Add one to the inst count
		addi $a0, $a0, 0x4 #  Add 4 to the data segment pointer
		
		srl $t3, $t2, 26 #  Isolate the op code
		
		#  As branch instructions take 2 ARM operations, check if ARM, and add 1
		li $t2, 0x1
		beq $t2, $t3, ciBranch
		
		sll $t2, $t2, 0x2
		beq $t2, $t3, ciBranch
		
		j ciLoop #  Loop
		
		ciBranch:
			#  Looks like its a branch instruction
			addi $t0, $t0, 0x1 #  Add one to the inst count
		
		j ciLoop #  Loop
	DciLoop:
	
	sw $t0, armCount #  Store the count into memory
	
	#  Allocate armCount bytes
	li $v0, 9
	move $a0, $t0
	syscall
		
	sw $v0, branchTree #  Store the base of the branchTree into memory
	
	lw $a0, -24($fp) #  Reload the first argument to the function from memory
	li $t1, -1 #  Redeclare the ending character
	li $t4, 0x0
	la $t5, branchTree
	ciLoop2:
		lw $t2, 0($a0) #  Load the value of 
		beq $t2, $t1, DciLoop2 #  Check if the ending character
			
		srl $t3, $t2, 26
		#  Op code stored in $t3, $t2+ free
			
		addi $a0, $a0, 0x4
			
		#  As branch instructions take 2 ARM operations, check if ARM, and add 1
		li $t2, 0x1
		beq $t2, $t3, ciBranch2
		sll $t2, $t2, 0x2
		beq $t2, $t3, ciBranch2
			
		#  Add current place to base of branchTree
		add $t2, $t5, $t4
		#  Store a 0 as its not a branch...
		sb $0, 0($t2)
			
		#  Move one address ahead in bTree
		addi $t4, $t4, 0x1
			
		j ciLoop2
			
		ciBranch2:
			#  Compute address of branchTree
			add $t2, $t5, $t4
			#  Load the value of 1
			li $t3, 1
				
			#  Store a 1 in the cmp spot
			sb $t3, 0($t2)
			#  Move one address ahead in bTree
			addi $t4, $t4, 0x1
				
			#  Compute address of branchTree
			add $t2, $t5, $t4
			#  Add 1 + 1 = 2
			addi $t3, $t3, 1
				
			#  Store a 2 in the BRANCH spot
			sb $t3, 0($t2)
				
			#  Move one address ahead in bTree
			addi $t4, $t4, 0x1
				
			
		j ciLoop2
	DciLoop2:
	
	move $v0, $t0
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	lw $t2, -16($fp)
	lw $t3, -20($fp)
	lw $a0, -24($fp)
	lw $t4, -28($fp)
	lw $t5, -32($fp)
	#  Unwind the stack
	addi $sp, $sp, 36
	lw $fp, -4($sp)
	jr $ra

# rriShiftOperation
# 
# $a0 => operation pre
# $a1 => shift operand
# $v0 <= translated ARM command
# 
# 1110 0001 1010 (rtData->ARM) (rdData->ARM) (shamtData) 000 (rtData->ARM)
# 

rriShiftOperation:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -16
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $a0, -12($fp)
	sw $a1, -16($fp)
	
	#  Insert the opp pre
	sll $t0, $a0, 20
	
	#  Insert rDestination Data
	la $a0, rdData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rrisoInvalid
	
	sll $v0, $v0, 12
	or $t0, $v0, $t0
	
	#  Insert Shift Amount Data
	lw $v0, shamtData
	
	sll $v0, $v0, 7
	or $t0, $v0, $t0
	
	#  Insert shift type
	sll $v0, $a1, 5
	or $t0, $v0, $t0
	
	#  Insert rSource Data
	la $a0, rtData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rrisoInvalid
	
	sll $a0, $v0, 16
	or $t0, $a0, $t0
	or $t0, $v0, $t0
	
	move $v0, $t0
	
	j rrisoExit
	
	rrisoInvalid:
		li $v0, -1
	rrisoExit:
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	lw $a1, -16($fp)
	#  Unwind the stack
	addi $sp, $sp, 20
	lw $fp, -4($sp)
	jr $ra

# rrrShiftOperation
# 
# $a0 => operation pre
# $a1 => shift operand
# $v0 <= translated ARM command
# 
# 1110 0001 1010 (rtData->ARM) (rdData->ARM) (rsData->ARM) 001 (rtData->ARM)
# 

rrrShiftOperation:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -16
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $a0, -12($fp)
	sw $a1, -16($fp)
	
	#  Insert the opp pre
	sll $t0, $a0, 20
	
	#  Insert rDestination Data
	la $a0, rdData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rrrsoInvalid
	
	sll $v0, $v0, 12
	or $t0, $v0, $t0
	
	#  Insert Shift Amount Data
	la $a0, rsData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rrrsoInvalid
	
	sll $v0, $v0, 8
	or $t0, $v0, $t0
	
	#  Insert shift type
	sll $v0, $a1, 5
	or $t0, $v0, $t0
	
	#  Insert rs selector bit
	li $v0, 0x1
	sll $v0, $v0, 4
	or $t0, $v0, $t0
	
	#  Insert rSource Data
	la $a0, rtData
	jal convertMIPStoARMregister
	
	#  Check to see if this was a valid register
	bltz $v0, rrrsoInvalid
	
	sll $a0, $v0, 16
	or $t0, $a0, $t0
	or $t0, $v0, $t0
	
	move $v0, $t0
	
	j rrisoExit
	
	rrrsoInvalid:
		li $v0, -1
	rrrsoExit:
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	lw $a1, -16($fp)
	#  Unwind the stack
	addi $sp, $sp, 20
	lw $fp, -4($sp)
	jr $ra

MIPStoARM:
	#  Prepare the stack
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -40
	#  Store the values
	sw $ra, -4($fp)
	sw $s0, -8($fp)
	sw $t0, -12($fp)
	sw $t1, -16($fp)
	sw $t2, -20($fp)
	sw $t3, -24($fp)
	sw $t4, -28($fp)
	sw $t5, -32($fp)
	sw $t6, -36($fp)
	sw $t7, -40($fp)
	
	move $s0, $a0 #  Backup the variable of $a0 into $s0, as we will be manipulating both seperatly
	
	jal countInstructions #  Count the number of instructions, return to $v0
	
	move $a0, $v0 #  Number of ARM instructions now available in $v0
	
	jal allocateARMword #  Allocate a contingeous memory store for all the ARM instructions
	
	lw $t9, armAddress #  Address of memory store at armAddress:
	
	li $t8, 0x0 #  Address space offset (0 indexed)
	
	beginTranslation:
	
	lw $t0, 0($s0) #  Load the MIPS instruction into $t0
	
	li $t1, -1 #  Value for the Sentinel
	beq $t0, $t1, hitSentinel #  Check if it matches
	
	#  Step 1: Check type of operation, check (31-26)
	srl $t1, $t0, 26 #  store op code into $t1
	
	#  Check if it matches a 0 style op code
	#  0000 00 => (AND | OR | ADD | SUB | SRA | SRL | SLL | SRLV | SLLV | JR)
	beqz $t1, opZero
	
	#  As the remaining operations are of I type, parse the I type instructions early
	move $a0, $s0 #  Move the address of the instruction into $a0
	jal parseIType #  Parse the I type instruction, loading the values for the field into memory
	
	#  0000 01 => (BGEZ)
	li $t2, 0x1
	beq $t1, $t2, fctBGEZ #  Check if it matches a BGEZ
	
	#  0001 00 => (BEQ)
	li $t2, 0x4
	beq $t1, $t2, fctBEQ #  Check if it matches a BEQ
	
	#  The following commands require the rotation to be calculated, parseIType called above will return -1 into $v0 if the computation of the rotation values goes astray. Therefore it is crutial to check to see if the rotation was computed, else print the no-op
	li $t2, -1
	beq $t2, $v0, fctINVALID #  Check if the I type translation was sucesfull
	
	#  0011 00 => 0xC (ANDI)
	li $t2, 0xC
	beq $t1, $t2, fctANDI #  Check if it matches a ANDI
	
	#  0011 01 => (ORI)
	li $t2, 0xD
	beq $t1, $t2, fctORI #  Check if it matches a ORI
	
	#  0010 00 => (ADDI)
	li $t2, 0x8
	beq $t1, $t2, fctADDI #  Check if it matches a ADDI
	
	j fctINVALID #  As it does not match any of the above instructions, print an invalid function
	
	opZero:
		#  As all instructions that have an op code of zero are R type instructions, parse the R type instruction
		move $a0, $s0 #  Move the address of the instruction into $a0
		jal parseRType
		
		#  Shift the function code into $t1 from the full function call in $t0
		sll $t1, $t0, 26
		srl $t1, $t1, 26
		
		# 0x00 => (SLL)
		# 0x03 => (SRA)
		# 0x20 => (ADD)
		# 0x22 => (SUB)
		# 0x24 => (AND)
		# 0x25 => (OR)
		# 0x02 => (SRL)
		# 0x04 => (SLLV)
		# 0x06 => (SRLV)
		# 0x08 => (JR)
		
		#  Match the operation to the function code as described in the table above
		
		beqz $t1, fctSLL
		
		li $t2, 0x8
		beq $t2, $t1, fctJR
		
		li $t2, 0x03
		beq $t2, $t1, fctSRA
		
		li $t2, 0x20
		beq $t2, $t1, fctADD
		
		li $t2, 0x22
		beq $t2, $t1, fctSUB
		
		li $t2, 0x24
		beq $t2, $t1, fctAND
		
		li $t2, 0x25
		beq $t2, $t1, fctOR
		
		li $t2, 0x02
		beq $t2, $t1, fctSRL
		
		li $t2, 0x4
		beq $t2, $t1, fctSLLV
		
		li $t2, 0x6
		beq $t2, $t1, fctSRLV
		
		#  If it does not match any of the above function types for a 0x0 op code instruction, print an invalid function
		j fctINVALID
	
	fctOR:
		#  => 1110 0001 1000 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		#  1110 0001 1000 => 0xE18
		#  
		#  As this matches the OR function, load the prefix to the instruction 0xE18 into $a0 for processing by 0xE18
		#  
		li $a0, 0xE18
		jal rrOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctSRA:
		# => 1110 0001 1010 (rtData->ARM) (rdData->ARM) (shamtData) 010 (rtData->ARM)
		#  1110 0001 1010 => 0xE1A
		#  
		#  As this matches the SRA function, load the prefix to the instruction 0xE1A into $a0 for processing by 0xE1A
		#  
		li $a0, 0xE1A
		li $a1, 0x2
		jal rriShiftOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctADD:
		#  => 1110 0000 1000 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		#  1110 0000 1000 => 0xE08
		#  
		#  As this matches the ADD function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE08
		#  
		li $a0, 0xE08
		jal rrOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctSUB:
		#  => 1110 0000 0100 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		#  1110 0000 0100 => 0xE04
		#  
		#  As this matches the SUB function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE04
		#  
		li $a0, 0xE04
		jal rrOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctAND:
		#  => 1110 0000 0000 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		#  1110 0000 0000 => 0xE00
		#  
		#  As this matches the AND function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE00
		#  
		li $a0, 0xE00
		jal rrOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctSRL:
		#  => 1110 0001 1010 (rtData->ARM) (rdData->ARM) (shamtData) 001 (rtData->ARM)
		#  1110 0000 1010 => 0xE08
		#  
		#  As this matches the SRL function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE18
		#  
		li $a0, 0xE1A
		li $a1, 0x1
		jal rriShiftOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctSLL:
		#  => 1110 0001 1010 (rtData->ARM) (rdData->ARM) (shamtData) 000 (rtData->ARM)
		#  1110 0001 1010 => 0xE1A
		#  
		#  As this matches the SLL function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE1A
		#  
		li $a0, 0xE1A
		li $a1, 0x0
		jal rriShiftOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctSLLV:
		#  => 1110 0001 1010 (rtData->ARM) (rdData->ARM) (rsData->ARM) 1 00 (rtData->ARM)
		#  1110 0001 1010 => 0xE1A
		#  
		#  As this matches the SLLV function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE1A
		#  
		li $a0, 0xE1A
		li $a1, 0x0
		jal rrrShiftOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctSRLV:
		# => 1110 0001 1010 (rtData->ARM) (rdData->ARM) (rsData->ARM) 1 01 (rtData->ARM)
		#  1110 0001 1010 => 0xE1A
		#  
		#  As this matches the SRLV function, load the prefix to the instruction 0xE08 into $a0 for processing by 0xE1A
		#  
		li $a0, 0xE1A
		li $a1, 0x1
		jal rrrShiftOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
	
	fctJR:
		#  The jump instruction is prefixed by 0xE
		li $a0, 0xE
		jal jumpOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
	
	fctANDI:
		#  => 1110 0010 0000 (rsData->ARM) (rdData->ARM) (rotateData) (immData)
		#  Add Prefix and process using the register + immediete operation method
		li $a0, 0xE20
		jal riOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctORI:
		# => 1110 0011 1000 (rsData->ARM) (rdData->ARM) (rotateData) (immData)
		#  Add Prefix and process using the register + immediete operation method
		li $a0, 0xE38
		jal riOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctADDI:
		# => 1110 0010 1000 (rsData->ARM) (rdData->ARM) (rotateData) (immData)
		#  Add Prefix and process using the register + immediete operation method
		li $a0, 0xE28
		jal riOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j endOP
		
	fctBGEZ:
		#  Already parsed I type instruction foramat.
		#  Add the prefix value to $t2
		li $t2, 0xE35
		sll $t2, $t2, 20
		
		#  Load the source register data and parse it into the ARM regiser
		la $a0, rsData
		jal convertMIPStoARMregister
		
		bltz $v0, fctINVALID #  Check to see if this was a valid register
		
		sll $v0, $v0, 16 #  Move the result into position
		
		or $t0, $t2, $v0 #  Add it to the register that we are compiling the ARM instruction
		
		sw $t0, 0($t9) #  Store the CMP operation into the data segment
		
		addi $t8, $t8, 1 #  Add one to the inst count reference
		addi $t9, $t9, 4 #  Add 4 to the data segment pointer
		
		move $a0, $t8 #  Move the value of the inst count reference into $a0
		la $a1, addressData #  Move the address of the addressData into $a1
		jal processOffset #  Translate the offset from a MIPS offset into a ARM offset
		
		li $t0, 0xAA #  Load the prefix of the BGEZ operation
		sll $t0, $t0, 24 #  Shift it into position
		
		or $t0, $t0, $v0 #  Add it to the register that we are compiling the ARM instruction
		
		sw $t0, 0($t9) #  Store the BGEZ instruction in the data segment
		
		#  FINISHED PROCESSING
		addi $s0, $s0, 0x4 #  Add 4 to the MIPS reading pointer
		addi $t9, $t9, 4 #  Add 4 to the data segment pointer
		addi $t8, $t8, 1 #  Add one to the inst count reference
		
		j beginTranslation #  Loop
	
	fctBEQ:
		#  Already parsed I type instruction foramat.
		#  Add the prefix value to $t2
		li $t2, 0xE15
		sll $t2, $t2, 20
		
		#  Load the source register data and parse it into the ARM regiser
		la $a0, rsData
		jal convertMIPStoARMregister
		
		bltz $v0, fctINVALID #  Check to see if this was a valid register
		
		sll $v0, $v0, 16 #  Move the result into position
		
		or $t0, $t2, $v0 #  Add it to the register that we are compiling the ARM instruction
		
		#  Load the comparison data into the $a0 register to convert from MIPS to arm style register
		la $a0, rtData
		jal convertMIPStoARMregister
		
		bltz $v0, fctINVALID #  Check to see if this was a valid register
		
		or $t0, $t0, $v0 #  Add it to the register that we are compiling the ARM instruction
		
		sw $t0, 0($t9) #  Store the CMP operation into the data segment
		
		addi $t8, $t8, 1 #  Add one to the inst count reference
		addi $t9, $t9, 4 #  Add 4 to the data segment pointer
		
		move $a0, $t8 #  Move the value of the inst count reference into $a0
		la $a1, addressData #  Move the address of the addressData into $a1
		jal processOffset #  Translate the offset from a MIPS offset into a ARM offset
		
		li $t0, 0x0A #  Load the prefix of the BEQ operation
		sll $t0, $t0, 24 #  Shift it into position
		
		or $t0, $t0, $v0 #  Add it to the register that we are compiling the ARM instruction
		
		sw $t0, 0($t9) #  Store the BEQ instruction in the data segment
		
		#  FINISHED PROCESSING
		addi $s0, $s0, 0x4 #  Add 4 to the MIPS reading pointer
		addi $t9, $t9, 4 #  Add 4 to the data segment pointer
		addi $t8, $t8, 1 #  Add one to the inst count reference
		
		j beginTranslation #  Loop
		
	

	fctINVALID:
		#  => 1110 0011 1010 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		li $a0, 0xE1A
		
		#  Zero all data register to ensure that R0 is the only register printned
		sw $0, rotateData
		sw $0, immData
		sw $0, rsData
		sw $0, rtData
		
		#  Parse the above data as a ri operation, with the offset mentioned above, it will interpret it as a MOV
		jal riOperation
		
		move $t0, $v0 #  Move the value of the ARM instruction into the $t0 reg
		
		j kdone #  Loop
		
	endOP:
	
	#  Check to see if any operation was unsucesfull, if so, just print a Invalid function
	li $t1, -1
	beq $t1, $t0, fctINVALID
	
	kdone:
	
	sw $t0, 0($t9) #  Store the ARM instruction into the data segment
	
	#  FINISHED PROCESSING
	addi $s0, $s0, 0x4 #  Add 4 to the MIPS reading pointer
	addi $t9, $t9, 4 #  Add 4 to the data segment pointer
	addi $t8, $t8, 1 #  Add one to the inst count reference
	j beginTranslation #  Loop
	
	hitSentinel:
	
	#  Prepare the values for the return as per requested by the spec
	lw $v0, armCount
	lw $v1, armAddress
	
	#  Restore the values from the stack
	lw $ra, -4($fp)
	lw $s0, -8($fp)
	lw $t0, -12($fp)
	lw $t1, -16($fp)
	lw $t2, -20($fp)
	lw $t3, -24($fp)
	lw $t4, -28($fp)
	lw $t5, -32($fp)
	lw $t6, -36($fp)
	lw $t7, -40($fp)
	#  Unwind the stack
	addi $sp, $sp, 44
	lw $fp, -4($sp)
	jr $ra
	