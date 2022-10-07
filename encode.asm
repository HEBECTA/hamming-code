
section .data

    SYS_OPEN        equ     2
    SYS_READ        equ     0
	SYS_WRITE       equ     1
	SYS_CLOSE       equ     3
	SYS_EXIT        equ     60

    RET_OK          equ     0
    RET_ERROR       equ     1

    STDOUT          equ     1


    arr     dd      0xd, 0xb, 0x8, 0x7, 0x4, 0x2, 0x1
    len     dw         7

    cmd_ard_addr     dq      0
    fd               dq      0 
    NULL             equ     0
    LF               equ     10
    newLine          db      LF, NULL

    msg             db  "my message !"


section .text


global main
main:

    ; read passed parameters
    ; rdi num
    ; rsi loc
    cmp rdi, 3
    jne exit_cmd_args

    mov r12, rdi
    mov r13, rsi

    ;mov [cmd_ard_addr], rsi
    ;mov rsi, [rsi]
printArguments:
    mov rdi, newLine
    call printString

    mov rbx, 0

printLoop:
    mov rdi, qword [r13+rbx*8]
    call printString

    mov rdi, newLine
    call printString

    inc rbx
    cmp rbx, r12
    jl printLoop


    ;mov rax, SYS_WRITE
    ;mov rsi, [rsi+8]
    ;mov edi, STDOUT
    ;syscall


    ; open file
    ;mov rax, SYS_OPEN
    ;mov rdi, [rbx]
    ;mov rsi, SYS_READ
    ;syscall

    ;cmp rdi, 0
    ;jl open_file_error

    ;mov qword [fd], rax
    
    mov rax,    SYS_EXIT
    mov rdi,    RET_OK
    syscall

exit_cmd_args:

    mov rax,    SYS_EXIT
    mov rdi,    RET_ERROR
    syscall

open_file_error:

    mov rax,    SYS_EXIT
    mov rdi,    RET_ERROR
    syscall

global printString
printString:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, rdi
    mov rdx, 0
strCountLoop:
    cmp byte [rbx], NULL
    je strCountDone

    inc rdx
    inc rbx
    jmp strCountLoop

strCountDone:

    cmp rdx, 0
    je prtDone

    mov rax, SYS_WRITE
    mov rsi, rdi
    mov edi, STDOUT

prtDone:

    pop rbx
    pop rbp
    ret

global encode
encode:


    ret