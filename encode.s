#  PURPOSE:   This program converts an input file into hamming code and stores
# 	     the result into the output file.
# 
#  PROCESSING: 1) Open the input file
#              2) Open the output file
#              3) While we're not at the end of the input file
#                a) read part of the file into our read buffer
#                b) go through each byte of the read buffer
#                   - convert lower nibble and store in write buffer
#                   - convert upper nibble and store in write buffer
#                c) write the write buffer to the output file

.section .data
    #  The encoding matrix G
    encode_matrix: .byte 0b1101, 0b1011, 0b1000, 0b0111, 0b0100, 0b0010, 0b0001

# # # # # # # CONSTANTS# # # # # # # # 

	#  System call numbers
	.equ SYS_OPEN, 2
	.equ SYS_READ, 0
	.equ SYS_WRITE, 1
	.equ SYS_CLOSE, 3
	.equ SYS_EXIT, 60

	#  Return Values
	.equ RET_OK, 0
	.equ RET_ERROR, 1

	#  Options for open   (look at /usr/include/asm/fcntl.h for
	#                     various values.  You can combine them
	#                     by adding them)
	.equ O_RDONLY, 0                  #  Open file options - read-only
	.equ O_CREAT_WRONLY_TRUNC, 03101  #  Open file options - these options are:
	                                  #  CREAT - create file if it doesn't exist
	                                  #  WRONLY - we will only write to this file
	                                  #  TRUNC - destroy current file contents, if any exist

	.equ O_PERMS, 0666                #  Read & Write permissions for everyone

	#  End-of-file result status
	.equ END_OF_FILE, 0  #  This is the return value of read() which
	                     #  means we've hit the end of the file

# # # # # # # BUFFERS# # # # # # # # # 

.section .bss
	#  This is where the data is loaded into from the data file
	.equ READ_BUFFER_SIZE, 250
	.lcomm READ_BUFFER_DATA, READ_BUFFER_SIZE
	#  This is where the data is written to after conversion
	#  and from here it is also written to the output file
	.lcomm WRITE_BUFFER_DATA, READ_BUFFER_SIZE*2


# # # # # # # PROGRAM CODE# # # 

	.section .text

	#  STACK POSITIONS
	.equ ST_SIZE_RESERVE, 16 #  Space for local variables
	#  Note: Offsets are RBP-based, which is set immediately at program start
	.equ ST_FD_IN, -16       #  Local variable for input file descriptor
	.equ ST_FD_OUT, -8       #  Local variable for output file descriptor
	.equ ST_ARGC, 0          #  Number of arguments
	.equ ST_ARGV_0, 8        #  Name of program
	.equ ST_ARGV_1, 16       #  Input file name
	.equ ST_ARGV_2, 24       #  Output file name

	.globl _start
_start:
	# # # INITIALIZE PROGRAM# # # 
	movq %rsp, %rbp             # Create new stack frame
	subq $ST_SIZE_RESERVE, %rsp # Allocate space for our file descriptors on the stack
	###CHECK PARAMETER COUNT###
	cmpq $3, ST_ARGC(%rbp)
	je open_files
	movq $-1, %rdi              # Our return value for parameter problems
	movq $SYS_EXIT, %rax
	syscall

open_files:
open_fd_in:
	###OPEN INPUT FILE###
	movq ST_ARGV_1(%rbp), %rdi  # Input filename into %rdi
	movq $O_RDONLY, %rsi        # Read-only flag
	movq $O_PERMS, %rdx         # This doesn't really matter for reading
	movq $SYS_OPEN, %rax        # Specify "open"
	syscall 	                # Call Linux
	cmpq $0, %rax               # Check success
	jl exit_error               # In case of error simply terminate

store_fd_in:
	movq  %rax, ST_FD_IN(%rbp)  # Save the returned file descriptor

open_fd_out:
	###OPEN OUTPUT FILE###
	movq ST_ARGV_2(%rbp), %rdi        # Output filename into %rdi
	movq $O_CREAT_WRONLY_TRUNC, %rsi  # Flags for writing to the file
	movq $O_PERMS, %rdx               # Permission set for new file (if it's created)
	movq $SYS_OPEN, %rax              # Open the file
	syscall                           # Call Linux
	cmpq $0, %rax                     # Check success
	jl close_input_exit_error         # In case of error close input file (already open!)

store_fd_out:
	movq %rax, ST_FD_OUT(%rbp)        # Store the file descriptor

read_loop_begin:

	###READ IN A BLOCK FROM THE INPUT FILE###
	movq ST_FD_IN(%rbp), %rdi     # Get the input file descriptor
	movq $READ_BUFFER_DATA, %rsi       # The location to read into
	movq $READ_BUFFER_SIZE, %rdx       # The size of the buffer
	movq $SYS_READ, %rax
	syscall                       # Size of buffer read is returned in %eax

	###EXIT IF WE'VE REACHED THE END###
	cmpq $END_OF_FILE, %rax       # Check for end of file marker
	je end_loop                   # If found (or error), go to the end
	jl close_output_exit_error    # On error just terminate

	# S E T   L O O P
	movq %rax, %rcx # buffer size => n of the loop
	movq $0, %rbx 	# iterrator for read buffer
	movq $0, %rdx 	# iterrator for write buffer

encode_nibbles:

	movb READ_BUFFER_DATA(%rbx, 1), %dil
	movq %rdi, %r13

	pushq %rcx
	pushq %rdx

	call encode	 						# convert lower nibble

	popq %rdx
	popq %rcx

	incq %rbx

	movb %al, WRITE_BUFFER_DATA(%rdx, 1)	# store lower nibble in write buffer
	incq %rdx

	
	movq %r13, %rdi
	shrq $4, %rdi

	pushq %rcx
	pushq %rdx

	call encode

	popq %rdx
	popq %rcx
	
	movb %al, WRITE_BUFFER_DATA(%rdx, 1)	# store higher nibble in write buffer
	incq %rdx

	loop encode_nibbles

	
    movq %rdx, %r12

write_to_file:

	###WRITE THE BLOCK OUT TO THE OUTPUT FILE###
	movq ST_FD_OUT(%rbp), %rdi    # File to use
	movq $WRITE_BUFFER_DATA, %rsi # Location of buffer
	# movq %rcx, %rdx               # Size of buffer
	movq $SYS_WRITE, %rax
	syscall
	###CHECK WRITE SUCCESS###
	cmpq %rax, %r12               # Compare number read to written
	jne close_output              # If not the same, terminate program
	###CONTINUE THE LOOP###
	jmp read_loop_begin

end_loop:  

close_output:                     # are the same: we just close both files
	###CLOSE THE FILES###
	# NOTE - we don't need to do error checking on these, because 
	#        error conditions don't signify anything special here
	#        and there is nothing for us to do anyway
	movq ST_FD_OUT(%rbp), %rdi
	movq $SYS_CLOSE, %rax
	syscall
close_input:
	movq ST_FD_IN(%rbp), %rdi
	movq $SYS_CLOSE, %rax
	syscall

exit:
	###EXIT###
	movq $RET_OK, %rdi          # Standard return value for all cases
	movq $SYS_EXIT, %rax
	syscall

close_output_exit_error:
	movq ST_FD_OUT(%rbp), %rdi
	movq $SYS_CLOSE, %rax
	syscall

close_input_exit_error:
	movq ST_FD_IN(%rbp), %rdi
	movq $SYS_CLOSE, %rax
	syscall

exit_error:
	movq $RET_ERROR, %rdi          
	movq $SYS_EXIT, %rax
	syscall


#  ----------------------------------------------------------------------------------------------------

# # # # # FUNCTION encode
# 
# PURPOSE:   This function actually implements the conversion to hamming 8,4
# 
# INPUT:     The first parameter (DIL) is the 8-bit value that we want to encode.
#            Since we encode into the hamming 8,4 format we are only interested in
#            the lower nibble (a nibble being half a byte or 4-bit) of the input byte.
#            Our input format looks like:
#      bit    7       0
#            +----+----+
#            |xxxx|vvvv|
#            +----+----+
#            x = dont care
#            v = value to encode
# 
# OUTPUT:
#            Return value: This function returns one byte containing
#            the hamming encoded lower nibble of the input value
#            using "encode_matrix" for calculation
# 
# VARIABLES:
# 
encode:
	# P R O L O G U E
	push %rbp			# create stack frame
	movq %rsp, %rbp		# create stack frame

	# F U N C T I O N       L O G I C

	# return answer
	mov $0, %rax

	# loop iteration
	mov $7, %rcx

	# matrix iteration
	mov $0, %rdx

matrix_mul:

	movb encode_matrix(%rdx, 1), %r12b
	andb %dil, %r12b
	inc %rdx
	popcnt %r12, %r12

	orb $0b111110, %r12b
	cmpb $0b111110, %r12b
	je even

not_even:
	addq $1, %rax
even:
	shl %rax

	loop matrix_mul

    shr %rax

	# E P I L O G U E
	movq %rbp, %rsp		# restore old stack frame
	pop %rbp			# restore old stack frame
	ret
	