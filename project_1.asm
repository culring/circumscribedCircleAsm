################################## DATA SECTION ##################################
	
	.data 
transformation:		.word 0x5BB360 # 24 bits of information about transforming (x, y) from
				       # one octant to zero octant; there are 3 bits for every octant, 
				       # respectively (from most significant bits) - [should x,y be swapped]
				       # [should y be negative][should x be negative]
modifier:		.byte 0x0 # 3 bits holding information about transformation actual (x, y) pair
padding:		.word 0x0 # padding of an output file
offset:			.word # offset to the pixel array in the file 
header: 		.byte # bitmap header
			0x42, 0x4D, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x36, 0x00, 0x00, 0x00,
			0x28, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01, 0x00,
	      		0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x13, 0x0B, 0x00, 0x00,
	      		0x13, 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
filename: 		.space 255 # buffer containing name of desired location of a file to save 
points:			.space 24 # coordinates of the triangle
returnAddress: 		.word 0x0 # space containing a return address
pixelArrayAddress:	.word 0x0 # an address of a pixel array 
pixelArraySize:		.word 0x0 # size of a pixel array
width:			.word 0x0 # width of the canvas

##################################    MACROS    ##################################

	############ reading an integer from the console ###########
	.macro read_int (%x)
	li $v0, 5
	syscall
	move %x, $v0
	.end_macro
	#################### printing integer ######################
	.macro print_int (%x)
	li $v0, 1
	move $a0, %x
	syscall
	.end_macro
	################### ending the program #####################
	.macro done
	li $v0,10
	syscall
	.end_macro
	############## printing string to the console ##############
	.macro print_str (%str)
	.data
string_label:	.asciiz %str
	.text
	li $v0, 4
	la $a0, string_label
	syscall
	.end_macro	
	################## swapping two registers ##################
	.macro swap (%r1, %r2)
	move $at, %r1
	move %r1, %r2
	move %r2, $at
	.end_macro
	######################### put pixel ########################
	.macro putPixel (%r1, %r2)
	
	# calculating position in the pixel array
	# 3*(y * width + x)
	mul $a2, %r2, $s1
	add $a2, $a2, %r1
	mul $a2, $a2, 3
	
	# must take care of padding space too
	# y * padding
	mul $a3, %r2, $k1
	# updating position
	add $a2, $a2, $a3
	# writing to the pixel array
	add $a3, $k0, $a2
	sb $zero, ($a3)
	sb $zero, 1($a3)
	sb $zero, 2($a3)
	.end_macro
	###################### opening a file ######################
	.macro openFile (%openingMode)
	li $a1, %openingMode
	li $v0, 13       # system call for opening file
 	syscall            # open a file (file descriptor returned in $v0)
  	bgez $v0, no_error
  	print_str ("File opening error. Program terminated")
  	done
no_error:
  	.end_macro
  	##################### writing to a file ####################
  	.macro writeToFile ()
writeToFile:
	li   $v0, 15       # system call for write to file
  	syscall            # write to file
  	bgez $v0, noWriteToFileError
  	print_str ("Couldn't write to file. Error")
  	li   $v0, 16       # system call for close file
  	syscall
	done
noWriteToFileError:
	.end_macro
	########################## modify ##########################
	# changing point ($a0, $a1) according to modifier
	# x2x1x0 - x0 = 1 means $a0 should be negative,
	# x1 = 1 means $a1 should be negative,
	# x2 = 1 means $a0, $a1 should be swapped
	.macro modify (%modifier)
	andi $a3, %modifier, 0x1
	beqz $a3, yNegative
	mul $a0, $a0, -1
	
yNegative:
	andi $a3, %modifier, 0x2
	beqz $a3, swap
	mul $a1, $a1, -1
	
swap:
	andi $a3, %modifier, 0x4
	beqz $a3, endModify
	# swapping
	move $at, $a0
	move $a0, $a1
	move $a1, $at
endModify:
	.end_macro
	############################################################

################################## MAIN SECTION ##################################

	.text
	.globl main	
main:
	# choosing between creating new file or writing in the existing one
	print_str ("In order to create a new file - type 0, otherwise - type 1: ")
	read_int ($t9)
	
	# reading name of a file
	print_str ("Give a name of a file where you want an image to be saved: ")
	li $v0, 8
	la $a0, filename
	li $a1, 255
	syscall
	
	# removing \n from filename string
	la $a1, filename
loopRemove:
	lb $a2, ($a1)
	beq $a2, '\n', remove
	addiu $a1, $a1, 1
	b loopRemove
remove:
	sb $zero, ($a1)
	
	# if using already existed file read a file header
	beq $t9, 1, readHeader
	
	# in other case get parameters of an image to be created
	print_str ("Give heidth and width of a canvas (each one in a new line): ")
	read_int ($s0)
	read_int ($s1)
	
	usw $s1, header+18
	usw $s0, header+22
	sw $s1, width 
	
	# go to the code section which gets from the user 
	# coordinates of a triangle
	j readCoordinates

readHeader:
	# opening file
	la $a0, filename
	openFile (0)
	move $s6, $v0

	# reading header
	move $a0, $v0
	la $a1, header
	li $a2, 54
	li $v0, 14
	syscall
	
	# saving width and height to the memory
	ulw $s1, header+18 # width
	sw $s1, width
	ulw $s0, header+22 # height
	
readCoordinates:
	# reading coordinates of a line segment
	print_str ("Please type coordinates of P1:\n")
	read_int ($t0)
	read_int ($t1)
	print_str ("Please type coordinates of P2:\n")
	read_int ($t2)
	read_int ($t3)
	print_str ("Please type coordinates of P3:\n")
	read_int ($t4)
	read_int ($t5)
	
	# saving coordinates of points to the memory
	usw $t0, points
	usw $t1, points+4
	usw $t2, points+8
	usw $t3, points+12
	usw $t4, points+16
	usw $t5, points+20
		
	# calculating size of the pixel aaray
	
	# total number of pixels
	mul $t7, $s1, 3
	move $s2, $t7
	mul $t7, $t7, $s0
	
	# including padding 
	
	# number of bytes per line mod 4
	andi $s2, $s2, 0x3
	# number of padding bytes in each line,
	# 4 - ($s2 mod 4)
	beqz $s2, zeroPadding
	mul $s2, $s2, -1
	addi $s2, $s2, 4
	# store padding to the memory
	sw $s2, padding
	# all pading space in the pixel array
	mul $s2, $s2, $s0
	# updating number of allocating bytes
	add $t7, $t7, $s2
	j endPadding
	
	# store zero padding to the memory
	# when there is no padding
zeroPadding:
	sw $zero, padding
	
endPadding:
	# allocating memory for the pixel array (sbrk)
	li $v0, 9
	move $a0, $t7
	syscall
	move $k0, $v0
	
	# writing size and address of the pixel array to the memory
	usw $k0, pixelArrayAddress
	usw $t7, pixelArraySize
	
	# in case we are creating a new file
	# we should fill the pixel array with FF bytes
	# in order to make the canvas white
	beq $t9, 0, fillWithZeros
	
	# in case we are writing to the existing file
	# reading the pixel array
	move $a0, $s6
	move $a1, $k0
	move $a2, $t7
	li $v0, 14
	syscall
	
	# system call for close file
	move $a0, $s6
	li   $v0, 16       
  	syscall
	
	# write in the pixel aray first line segment
	j draw

	# painting the canvas white
fillWithZeros:
	move $s2, $k0
	add $k0, $k0, $t7
makeWhiteLoop:
	beq $s2, $k0, endMakeWhiteLoop
	la $t6, 0xFFFFFFFF
	sw $t6, ($s2)
	addi $s2, $s2, 4
	j makeWhiteLoop
endMakeWhiteLoop:
	sub $k0, $k0, $t7
	
	# writing to the header information about size of the file
	addi $a0, $t7, 54
	usw $a0, header+2 
	
	# drawing the triangle - line by line
draw:
	# drawing first line
	jal drawLine
	
	# drawing second line
	ulw $t0, points+8
	ulw $t1, points+12
	ulw $t2, points+16
	ulw $t3, points+20
	jal drawLine
	
	# drawing third line
	ulw $t0, points+16
	ulw $t1, points+20
	ulw $t2, points
	ulw $t3, points+4
	jal drawLine
	
	# circle
	# calculating circle parameters
	jal circleParameters
	move $s2, $s0
	move $s3, $s1
	move $s4, $t4
	jal drawCircle
	
	# writing to the file

	# opening the file to write
	la $a0, filename
	openFile (1)
	
	# writing the header
	move $a0, $v0
	la $a1, header
	li $a2, 54
	writeToFile ()
	
	ulw $k0, pixelArrayAddress
	ulw $t7, pixelArraySize
	
	# writing the pixel array
	move $a1, $k0
	move $a2, $t7
	writeToFile ()

	# closing the file
	li   $v0, 16       
  	syscall

	done

################################## DRAWING LINE ##################################

drawLine:
	# checking from what octant this line is
	
	# calculating dx - t4 and dy - t5
	sub $t4, $t2, $t0
	sub $t5, $t3, $t1
	
	# calculating absolute values of dx and dy
	abs $s0, $t4
	abs $s1, $t5

	# checking to which octant the segment belongs
	blez $t5, octantFourToSeven
	blez $t4, octantTwoToThree
	bge $s1, $s0, octantOne
	# octant zero
	li $t6, 0
	b endOctant
	
octantOne:
	li $t6, 1
	b endOctant
	 
octantTwoToThree:
	bge $s0, $s1, octantThree
	# octant two
	li $t6, 2
	b endOctant
	
octantThree:
	li $t6, 3
	b endOctant
	
octantFourToSeven:
	bgez $t4, octantSixToSeven
	bge $s1, $s0, octantFive
	# octant four
	li $t6, 4
	b endOctant
	
octantFive:
	li $t6, 5
	b endOctant
	
octantSixToSeven:
	bge $s0, $s1, octantSeven
	# octant six
	li $t6, 6
	b endOctant
	
octantSeven:
	li $t6, 7
	 
endOctant:
	# calculating modifier value
	
	# calculating first bit of mask
	mul $t7, $t6, 3
	li $s0, 0x1
	move $k0, $zero
	# mask
	sllv $s0, $s0, $t7
	lw $s1, transformation
	and $s2, $s1, $s0
	beqz $s2, labelOne
	
	# x should be negative
	ori $k0, $k0, 0x1
	
labelOne:
	sll $s0, $s0, 1
	and $s2, $s1, $s0
	beqz $s2, labelTwo
	
	# y should be negative
	ori $k0, $k0, 0x2

labelTwo:
	sll $s0, $s0, 1
	and $s2, $s1, $s0
	beqz $s2, endOctantZero
	
	# swap needed
	ori $k0, $k0, 0x4

endOctantZero:	
	# saving modifier mask to memory
	sb $k0, modifier
	
	# switching line segment to octant zero
	# point P0
	move $a0, $t0
	move $a1, $t1
	modify ($k0)
	move $t0, $a0
	move $t1, $a1
	
	# point P1
	move $a0, $t2
	move $a1, $t3
	modify ($k0)
	move $t2, $a0
	move $t3, $a1
	
	# if we have a line segment from the second
	# or sixth octant, we should change modifier
	beq $t6, 2, twoOrSixOct
	beq $t6, 6, twoOrSixOct
	j nextSection
twoOrSixOct:
	xor $k0, 0x3
	sb $k0, modifier

nextSection:
	# drawing line
	
	# dx = x1 - x0, dy = y1 - y0
	sub $t4, $t2, $t0
	sub $t5, $t3, $t1
	# D = 2*dy - dx
	move $s2, $t5
	sll $s2, $s2, 1
	sub $s2, $s2, $t4
	# y = y0
	move $s3, $t1
	# x = x0
	move $s4, $t0
	# padding
	lw $k1, padding
	
	# loading address of the pixel array
	# and its size
	ulw $k0, pixelArrayAddress
	ulw $t7, pixelArraySize
	
	# loading width
	ulw $s1, header+18
	
	# loading modifier
	lb $t0, modifier
	
plotLineLoop:
	bgt $s4, $t2, endPlotLineLoop
	
	# plot (x, y)
	
	# transforming coordinates of points to
	# its older state (before doing symmetry)
	move $a0, $s4
	move $a1, $s3
	modify ($t0)
	move $t8, $a0
	move $t9, $a1
	
	putPixel ($t8, $t9)
	
	blez $s2, lessEqualZero
	# y = y + 1
	addi $s3, $s3, 1
	# D = D - 2*dx
	move $at, $t4
	sll $at, $at, 1
	sub $s2, $s2, $at
	
lessEqualZero:
	# D = D + 2*dy
	move $at, $t5
	sll $at, $at, 1
	add $s2, $s2, $at
	# incrementing x
	addi $s4, $s4, 1
	j plotLineLoop
	
endPlotLineLoop:
	# returning to the beginning of the array
	sub $s5, $s7, $s6

	# go back and draw circle or next line segment
	jr $ra

########################## CALCULATING CIRCLE PARAMETERS #########################

	# calculating coordinates of the circumscribed cirle
	# and the radius
circleParameters:
	# loading coordinates of the triangle
	ulw $t0, points
	ulw $t1, points+4
	ulw $t2, points+8
	ulw $t3, points+12
	ulw $t4, points+16
	ulw $t5, points+20
	
	# |A|^2, |B|^2, |C|^2
	mul $s0, $t0, $t0
	mul $s4, $t1, $t1
	add $s0, $s0, $s4
	
	mul $s1, $t2, $t2
	mul $s4, $t3, $t3
	add $s1, $s1, $s4
	
	mul $s2, $t4, $t4
	mul $s4, $t5, $t5
	add $s2, $s2, $s4
	
	# Sx := $t6, Sy := $t7. a := $t8
	# $s4 := temporary
	
	# calculating 2*Sx
	mul $s3, $s0, $t3
	add $t6, $s3, $zero

	mul $s3, $s1, $t5
	add $t6, $t6, $s3
	
	mul $s3, $s2, $t1
	add $t6, $t6, $s3
	
	mul $s3, $s2, $t3
	sub $t6, $t6, $s3
	
	mul $s3, $s0, $t5
	sub $t6, $t6, $s3
	
	mul $s3, $s1, $t1
	sub $t6, $t6, $s3
	
	# calculating 2*Sy
	mul $s3, $s0, $t4
	add $t7, $s3, $zero

	mul $s3, $s1, $t0
	add $t7, $t7, $s3
	
	mul $s3, $s2, $t2
	add $t7, $t7, $s3
	
	mul $s3, $s2, $t0
	sub $t7, $t7, $s3
	
	mul $s3, $s0, $t2
	sub $t7, $t7, $s3
	
	mul $s3, $s1, $t4
	sub $t7, $t7, $s3
	
	# calculating a
	mul $s3, $t0, $t3
	add $t8, $s3, $zero

	mul $s3, $t2, $t5
	add $t8, $t8, $s3
	
	mul $s3, $t4, $t1
	add $t8, $t8, $s3
	
	mul $s3, $t4, $t3
	sub $t8, $t8, $s3
	
	mul $s3, $t0, $t5
	sub $t8, $t8, $s3
	
	mul $s3, $t2, $t1
	sub $t8, $t8, $s3
	
	# Ox = Sx/a
	mul $s2, $t8, 2
	div $s0, $t6, $s2
	# Oy = Sy/a
	div $s1, $t7, $s2
	
	sub $t2, $t0, $s0
	mul $t2, $t2, $t2
	sub $t3, $t1, $s1
	mul $t3, $t3, $t3
	add $t2, $t2, $t3
	
	# square root
	
	# op = $t3, res = $t4, one = $t5
	move $t3, $t2
	la $t5, 1
	sll $t5, $t5, 30
	move $t4, $zero
	
	# "one" starts at the highest power of four <= than the argument.
highestPowerLoop:
	ble $t5, $t3, oneLessEqualOp
	sra $t5, $t5, 2
	j highestPowerLoop
	
oneLessEqualOp:
	beqz $t5, endSquare
	add $s2, $t4, $t5
	blt $t3, $s2, opLessEqual
	sub $t3, $t3, $s2
	sll $s2, $t5, 1
	add $t4, $t4, $s2	
opLessEqual:
	sra $t4, $t4, 1
	sra $t5, $t5, 2
	j oneLessEqualOp

endSquare:
	ble $t3, $t5, squareJump
	addi $t4, $t4, 1
	
squareJump:
	jr $ra

################################# DRAWING CIRCLE #################################
drawCircle:
	# ($s2, $s3) - coordinates of the centre of the circle
	# $s4 - radius
	
	# x = radius, y = 0, err = 0
	move $t0, $s4
	move $t1, $zero
	move $t2, $zero
	
	lw $k1, padding
	lw $k0, pixelArrayAddress
	lw $t7, pixelArraySize
	lw $s1, width
	
loopDrawCircle:
	blt $t0, $t1, endLoopDrawCircle

	# x0+x, y0+y
	add $t8, $s2, $t0
	add $t9, $s3, $t1
	putPixel ($t8, $t9)
	# x0+x, y0-y
	sub $t9, $s3, $t1
	putPixel ($t8, $t9)
	# x0-x, y0-y
	sub $t8, $s2, $t0 
	putPixel ($t8, $t9)
	# x0-x, y0+y
	add $t9, $s3, $t1
	putPixel ($t8, $t9)
	
	# x0+y, y0+x
	add $t8, $s2, $t1
	add $t9, $s3, $t0
	putPixel ($t8, $t9)
	# x0+y, y0-x
	sub $t9, $s3, $t0 
	putPixel ($t8, $t9)
	# x0-y, y0-x
	sub $t8, $s2, $t1
	putPixel ($t8, $t9)
	# x0-y, y0+x
	add $t9, $s3, $t0
	putPixel ($t8, $t9)
	
	bgtz $t2, errGreaterZero
	# err <= 0
	# y += 1
	addi $t1, $t1, 1
	# err += 2y + 1
	addi $t2, $t2, 1
	sll $t3, $t1, 1
	add $t2, $t2, $t3
	j loopDrawCircle

errGreaterZero:
	addi $t0, $t0, -1
	addi $t2, $t2, -1
	sll $t3, $t0, 1
	sub $t2, $t2, $t3
	j loopDrawCircle
	
endLoopDrawCircle:
	jr $ra
