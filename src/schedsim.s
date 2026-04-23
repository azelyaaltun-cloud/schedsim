.code64
.section .bss
input_buf:      .space 256
output_buf:     .space 1024
temp_buf:       .space 256
proc_buf:       .space 160
process_count:  .space 4
current_time:   .space 4

# Round Robin helpers (optional)
rr_queue:        .space 64
rr_head:         .space 4
rr_tail:         .space 4

.section .data
newline:        .asciz "\n"

.section .text
.global _start

_start:
    # READ INPUT
    movq    $0, %rax
    movq    $0, %rdi
    lea     input_buf(%rip), %rsi
    movq    $256, %rdx
    syscall

    lea     input_buf(%rip), %rbx

    # 2. ALGORİTMA TESPİTİ
    cmpb    $70, (%rbx)         # 'F' (FCFS)
    je      _handle_fcfs
    cmpb    $83, (%rbx)         # 'S' (SJF)
    je      _handle_sjf

_handle_fcfs:
    movq    $1, %r15            # Algoritma ID: 1
    movq    $2, %r14            # 2 Sayı oku (Burst-Arrival)
    addq    $5, %rbx
    jmp     _common_parse

_handle_sjf:
    movq    $2, %r15            # Algoritma ID: 2
    movq    $1, %r14            # 1 Sayı oku (Sadece Burst)
    addq    $4, %rbx
    jmp     _common_parse

_common_parse:
    xorq    %rdi, %rdi          # Process sayacı

_parse_loop:
    movb    (%rbx), %al
    cmpb    $10, %al             # '\n'
    je      _simulation_start
    cmpb    $0, %al             # Null
    je      _simulation_start
    cmpb    $32, %al            # Boşluk
    je      _skip_space

    # Process ID Kaydet
    # rdi index, her process 16 byte. rdi*16 için shift kullanıyoruz.
    movq    %rdi, %r11
    shlq    $4, %r11            # r11 = rdi * 16
    lea     proc_buf(%rip), %rcx
    movb    %al, (%rcx, %r11)
    incq    %rbx                 # Harfi geç

    # Burst Time Oku
    incq    %rbx                # '-' karakterini atla
    movb    (%rbx), %al
    subb    $48, %al
    movzbq  %al, %rax
    movl    %eax, 4(%rcx, %r11)  # Burst kaydet (offset 4)
    movl    %eax, 12(%rcx, %r11) # Remaining kaydet (offset 12)
    incq    %rbx                 # Rakamı geç

    # FCFS ise Arrival Oku
    cmpq    $2, %r14
    jne     _finish_process


    incq    %rbx                # '-' karakterini atla
    movb    (%rbx), %al
    subb    $48, %al
    movzbq  %al, %rax
    movl    %eax, 8(%rcx, %r11)  # Arrival kaydet (offset 8)
    incq    %rbx                 # Rakamı geç

_finish_process:
    incq    %rdi
    jmp     _parse_loop

_skip_space:
    incq    %rbx
    jmp     _parse_loop

_simulation_start:
    movl    %edi, process_count(%rip)
    cmpq    $1, %r15
    je      _run_fcfs
    jmp     _run_sjf            # Değilse SJF'ye git


# FCFS 

_run_fcfs:
    movl    $0, current_time(%rip)
    movq    $0, %r13            # output_buf index
    movq    $-1, %r14           # çalışan process index
    movq    $0, %r15            # biten process sayısı

fcfs_simulation:
    movl    process_count(%rip), %r8d
    cmpq    %r15, %r8       # process_count == biten
    je      _output_final

    cmpq    $-1, %r14
    jne     fcfs_run_current

    movq    $999999, %r9        # min_arrival
    movq    $-1, %r10           # selected_index
    movq    $0, %r11            # i = 0

fcfs_select_loop:
    movl    process_count(%rip), %r8d
    cmpq    %r11, %r8
    je      fcfs_select_done

    movq    %r11, %rdx
    shlq    $4, %rdx
    lea     proc_buf(%rip), %rcx

    movl    12(%rcx, %rdx), %eax # remaining
    cmpl    $0, %eax
    jle     fcfs_select_next

    movl    8(%rcx, %rdx), %eax  # arrival
    movl    current_time(%rip), %ebx
    cmpl    %ebx, %eax
    jg      fcfs_select_next

    cmpq    %rax, %r9
    jle     fcfs_select_next

    movq    %rax, %r9
    movq    %r11, %r10

fcfs_select_next:
    incq    %r11
    jmp     fcfs_select_loop

fcfs_select_done:
    cmpq    $-1, %r10
    je      fcfs_idle
    movq    %r10, %r14

fcfs_run_current:
    movq    %r14, %rdx
    shlq    $4, %rdx
    lea     proc_buf(%rip), %rcx
    movb    (%rcx, %rdx), %al

    lea     output_buf(%rip), %rsi
    movb    %al, (%rsi, %r13)
    incq    %r13

    decl    12(%rcx, %rdx)      # remaining--
    cmpl    $0, 12(%rcx, %rdx)
    jne     fcfs_tick
    incq    %r15
    movq    $-1, %r14

fcfs_tick:
    incl    current_time(%rip)
    jmp     fcfs_simulation

fcfs_idle:
    lea     output_buf(%rip), %rsi
    movb    $88, (%rsi, %r13)   # 'X' (Idle)
    incq    %r13
    incl    current_time(%rip)
    jmp     fcfs_simulation


# SJF 

_run_sjf:
    movl    $0, current_time(%rip)
    movq    $0, %r13
    movq    $-1, %r14
    movq    $0, %r15

sjf_simulation:
    movl    process_count(%rip), %r8d
    cmpq    %r15, %r8
    je      _output_final

    cmpq    $-1, %r14
    jne     sjf_run_current

    # Seçim Yap (SJF: En kısa burst)
    movq    $999999, %r9        # min_burst
    movq    $-1, %r10           # selected_index
    movq    $0, %r11            # i = 0

sjf_select_loop:
    movl    process_count(%rip), %r8d
    cmpq    %r11, %r8
    je      sjf_select_done

    movq    %r11, %rdx
    shlq    $4, %rdx
    lea     proc_buf(%rip), %rcx

    movl    12(%rcx, %rdx), %eax # remaining
    cmpl    $0, %eax
    jle     sjf_select_next

    movl    4(%rcx, %rdx), %eax  # Burst Time (SJF kıstası)
    cmpq    %rax, %r9
    jle     sjf_select_next

    movq    %rax, %r9
    movq    %r11, %r10

sjf_select_next:
    incq    %r11
    jmp     sjf_select_loop

sjf_select_done:
    movq    %r10, %r14           
    jmp     sjf_run_current     

sjf_run_current:
    movq    %r14, %rdx
    shlq    $4, %rdx
    lea     proc_buf(%rip), %rcx
    movb    (%rcx, %rdx), %al

    lea     output_buf(%rip), %rsi
    movb    %al, (%rsi, %r13)
    incq    %r13
    
    decl    12(%rcx, %rdx)      # remaining--
    cmpl    $0, 12(%rcx, %rdx)
    jne     sjf_tick
    incq    %r15
    movq    $-1, %r14

sjf_tick:
    incl    current_time(%rip)
    jmp     sjf_simulation


# ÇIKTI 
_output_final:

    lea       output_buf(%rip), %rsi
    movb      $10, (%rsi, %r13)    # \n
    incq      %r13

    movq      $1, %rax
    movq      $1, %rdi
    movq      %r13, %rdx

    syscall
    
    jmp      .exit

.exit:
    movq     $60, %rax
    xorq     %rdi, %rdi
    syscall