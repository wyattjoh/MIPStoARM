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

armAddress: .word 0x0
armCount: .word 0x0

.text


#
#  allocateARMword
#  -------------------------
#
#  The address of the allocation will be stored in armAddress:
#
#  $a0 => Number of ARM instructions to allocate for (1 per word)
#

allocateARMword:
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
	
# 	1 byte is 8 bits
# 	1 word is 4 bytes
# 	1 inst is 1 word

# 	sbrk allocates $a0 bytes, address of the start returned at $v0
	li $t0, 0x4
	
	mult $a0, $t0
	
	mflo $a0
	li $v0, 9
	syscall
	
	lw $a0, -12($fp)
	sw $v0, armAddress
	
	li $t0, 0x1
	zeroLoop:
		beq $t0, $a0, EndzeroLoop
		sw $0, 0($v0)
		addi $v0, $v0, 4
		addi $t0, $t0, 0x1
		j zeroLoop
	EndzeroLoop:
	
# 	li $t0, -1
# 	sw $t0, 0($v0)
	
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
	addi $sp, $sp, -20
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)
	sw $t2, -16($fp)
	sw $t3, -20($fp)
	
	#  Calculate the distance from the most signifigant bit and least signifigant bit
	lw $t0, 0($a0)
	
	#  Counter for rotation
	li $t2, 0x0
	
	#  Phase 1: Determine the initial position of the least signifigant bit, for the shift value
	crP1:
		andi $t1, $t0, 0x01
		bne $t1, $0, EcrP1
		addi $t2, $t2, 0x1
		srl $t0, $t0, 0x1
		j crP1
	EcrP1:
	
	#  Move the immidiete value into $v1
	move $v1, $t0
	
	#  Divide the number of shifts to the left by 2 to determine the value of Rotate
	li $t1, 2
	div $t2, $t1
	
	#  If the value of rotate is not a multiple of 2, then error, we can't express this
	mfhi $t3
	bnez $t3, crError
	
	#  Move the value of the rotate param into $t2
	mflo $t2
	
	#  If false, then the number cant fit inside the rotate field
	sltiu $t3, $t2, 16
	beqz $t3, crError
	
	#  Move the rotate value into $v0
	move $v0, $t2
	
	#  Phase 2: Determine if this string is of valid length
	li $t3, 1
	li $t1, 1
	crP2:
		beq $t0, $t1, EcrP2
		addi $t3, $t3, 1
		srl $t0, $t0, 1
		j crP2
	EcrP2:
	
	#  Check to see if this value is legal to rotate (is less than 8 digits long)
	sltiu $t1, $t3, 9
	beqz $t1, crError
	
	j Ecr
	
	crError:
		li $v0, -1
		li $v1, -1
	Ecr:
		
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	lw $t2, -16($fp)
	lw $t3, -20($fp)
	#  Unwind the stack
	addi $sp, $sp, 24
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

parseIType:
	addi $sp, $sp, -4
	sw $fp, 0($sp)
	move $fp, $sp
	#  Grow the stack
	addi $sp, $sp, -16
	#  Store the values
	sw $ra, -4($fp)
	sw $t0, -8($fp)
	sw $t1, -12($fp)
	sw $t2, -16($fp)
	
	lw $t0, 0($a0)
	
	#  Masking element
	li $t1, 0xFF
	sll $t1, $t1, 8
	addi $t1, 0xFF
	
	and $t2, $t0, $t1
	
	sw $t2, addressData
	
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
	#  Unwind the stack
	addi $sp, $sp, 20
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
	
	# TODO: Check if register field is valid
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0x4
		
	la $a0, rdData
	jal convertMIPStoARMregister
	
	# TODO: Check if register field is valid
	
	or $t0, $v0, $t0
	sll $t0, $t0, 0xC
		
	la $a0, rtData
	jal convertMIPStoARMregister
	
	# TODO: Check if register field is valid
	
	or $t0, $v0, $t0
	
	move $v0, $t0
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $a0, -12($fp)
	#  Unwind the stack
	addi $sp, $sp, 16
	lw $fp, -4($sp)
	jr $ra

# countInstructions
# 
# $a0 => address of first instruction
# $v0 <= number of corrasponding ARM instructions

countInstructions:
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
	sw $a0, -24($fp)
	
	li $t0, 0x0
	li $t1, -1
	ciLoop:
		lw $t2, 0($a0)
		beq $t2, $t1, DciLoop
		addi $t0, $t0, 0x1
		
		srl $t3, $t2, 26
		#  Op code stored in $t3, $t2+ free
		
		#  As branch instructions take 2 ARM operations, check if ARM, and add 1
		li $t2, 0x1
		beq $t2, $t3, ciBranch
		
		sll $t2, $t2, 0x2
		beq $t2, $t3, ciBranch
		
		addi $a0, $a0, 0x4
		
		j ciLoop
		
		ciBranch:
			addi $t0, $t0, 0x1
		
		j ciLoop
	DciLoop:
	
	sw $t0, armCount
	
	#  Add one more for the sentinel
# 	addi $t0, $t0, 0x1
	
	move $v0, $t0
	
	lw $ra, -4($fp)
	lw $t0, -8($fp)
	lw $t1, -12($fp)
	lw $t2, -16($fp)
	lw $t3, -20($fp)
	lw $a0, -24($fp)
	#  Unwind the stack
	addi $sp, $sp, 28
	lw $fp, -4($sp)
	jr $ra

MIPStoARM:
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
	
	move $s0, $a0
	
	#  Count the number of instructions, return to $v0
	jal countInstructions
	
	#  Number of ARM instructions now available in $v0
	move $a0, $v0
	
	#  Allocate a contingeous memory store for all the ARM instructions
	jal allocateARMword
	
	#  Address of memory store at armAddress:
	lw $t9, armAddress
	
	beginTranslation:
	
	li $t1, -1
	lw $t0, 0($s0)
	#  $t0 now contains the full call
	
	beq $t0, $t1, hitSentinel
	
	#  Step 1: Check type of operation, check (31-26)
	srl $t1, $t0, 26
	#  $t1 now holds the op code
	
	#  0000 00 => (AND | OR | ADD | SUB | SRA | SRL | SLL | SRLV | SLLV | JR)
	beqz $t1, opZero
	
	#  0011 00 => 0xC (ANDI)
	li $t2, 0xC
	beq $t1, $t2, fctANDI
	
	#  0011 01 => (ORI)
	addi $t2, $t2, 0x1
	beq $t1, $t2, fctORI
	
	#  0000 01 => (BGEZ)
	li $t2, 0x1
	beq $t1, $t2, fctBGEZ
	
	#  0001 00 => (BEQ)
	sll $t2, $t2, 2
	beq $t1, $t2, fctBEQ
	
	#  0010 00 => (ADDI)
	sll $t2, $t2, 1
	beq $t1, $t2, fctADDI
	
	opZero:
		#  Load the information into memeory, parsing, all opcodes with 0 is automatically a R type instruction
		
		move $a0, $s0 #  Move the address of the instruction into $a0
		jal parseRType
		
		sll $t1, $t0, 26
		srl $t1, $t1, 26
		#  Now have the function code in $t1
		
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
		
		beqz $t1, fctSLL
		
		li $t2, 0x03
		beq $t2, $t1, fctSRA
		
		li $t2, 0x20
		beq $t2, $t1, fctADD
		
		addi $t2, 0x02
		beq $t2, $t1, fctSUB
		
		addi $t2, 0x02
		beq $t2, $t1, fctAND
		
		addi $t2, 0x01
		beq $t2, $t1, fctOR
		
		li $t2, 0x02
		beq $t2, $t1, fctSRL
		
		sll $t2, $t2, 1
		beq $t2, $t1, fctSLLV
		
		sll $t2, $t2, 1
		beq $t2, $t1, fctSRLV
		
		sll $t2, $t2, 1
		beq $t2, $t1, fctJR
		
		j fctINVALID
	
	fctOR:
		
# 		rsData: .word 0x0
# 		rtData: .word 0x0
# 		rdData: .word 0x0
# 		shamtData: .word 0x0
# 		addressData: .word 0x0
		
		#  => 1110 0001 1000 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		
		#	$a0 => location in memory to value of register number in MIPS
		#	$v0 <= register number in ARM
		
		#  Perform register translation
		# la $a0, rsData
		# jal convertMIPStoARMregister
		# move $t3, $v0
		# 
		# la $a0, rdData
		# jal convertMIPStoARMregister
		# move $t4, $v0
		# 
		# la $a0, rtData
		# jal convertMIPStoARMregister
		# move $t5, $v0
		
		li $a0, 0xE18 #  Begin translation
		jal rrOperation
		
		move $t0, $v0
		
		# sll $t6, $t6, 0x4
		
		# #  Add the rsData
		# 		or $t6, $t6, $t3
		# 		
		# 		sll $t6, $t6, 0x4
		# 		
		# 		#  Add the rdData
		# 		or $t6, $t6, $t4
		# 		
		# 		sll $t6, $t6, 0xC
		# 		
		# 		#  Add the rtData
		# 		or $t6, $t6, $t5
		
		j endOP
		
	fctSRA:
		
		j endOP
	fctADD:
		
		j endOP
	fctSUB:
		
		j endOP
	
	fctAND:
				#  => 1110 0000 0000 (rsData->ARM) (rdData->ARM) 0000 0000 (rtData->ARM)
		
		# #  Perform register translation
		# la $a0, rsData
		# jal convertMIPStoARMregister
		# move $t3, $v0
		# 
		# la $a0, rdData
		# jal convertMIPStoARMregister
		# move $t4, $v0
		# 
		# la $a0, rtData
		# jal convertMIPStoARMregister
		# move $t5, $v0
		
		li $a0, 0xE00 #  Begin translation
		jal rrOperation
		
		move $t0, $v0
		
		# sll $t6, $t6, 0x4
		
		# #  Add the rsData
		# or $t6, $t6, $t3
		# 
		# sll $t6, $t6, 0x4
		# 
		# #  Add the rdData
		# or $t6, $t6, $t4
		# 
		# sll $t6, $t6, 0xC
		# 
		# #  Add the rtData
		# or $t6, $t6, $t5
		
		j endOP
	
	fctSRL:
		
		j endOP
	
	fctSLL:
		
		j endOP
	
	fctSLLV:
		
		j endOP
	
	fctSRLV:
		
		j endOP
	
	fctJR:
		
		j endOP
	
	fctANDI:
		
		j endOP
	
	fctORI:
		
		j endOP
	
	fctBGEZ:
		
		j endOP
	
	fctBEQ:
		
		j endOP
	
	fctADDI:
		
		j endOP
		
	fctINVALID:
		
	endOP:
	
	sw $t0, 0($t9)
	
	#  FINISHED PROCESSING
	addi $s0, $s0, 0x4
	addi $t9, $t9, 4
	j beginTranslation
	
	hitSentinel:
		
	lw $v0, armCount
	lw $v1, armAddress
	
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
	