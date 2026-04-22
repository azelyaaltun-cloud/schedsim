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
    movq     $0, %rax
    movq     $0, %rdi
    lea      input_buf(%rip), %rsi
    movq     $256, %rdx
    syscall

    lea      input_buf(%rip), %rbx

    # FCFS Kontrolü
    cmpb     $70, (%rbx)         # 'F' karakteri
    je       _handle_fcfs

_handle_fcfs:
    movq $1, %r15               # Algoritma ID: 1
    movq $2, %r14               # 2 Sayı oku: Burst ve Arrival
    addq $5, %rbx               # "FCFS " atla
    jmp _common_parse        

_common_parse:
    xorq     %rdi, %rdi          # rdi = 0 (Süreç sayacı)

_parse_loop:
    # 1. BİTİŞ KONTROLÜ
    movb     (%rbx), %al
    cmpb     $10, %al            # '\n'
    je       _simulation_start
    cmpb     $0, %al             # Null
    je       _simulation_start
    cmpb     $32, %al            # Boşluk
    je       _skip_space

    # 2. PROCESS ID KAYDET (A, B...)
    # rdi index, her process 16 byte. rdi*16 için shift kullanıyoruz.
    movq     %rdi, %r11
    shlq     $4, %r11            # r11 = rdi * 16
    lea      proc_buf(%rip), %rcx
    movb     %al, (%rcx, %r11)
    incq     %rbx                # Harfi geç

    # 3. BURST TIME OKU
    incq     %rbx                # '-' karakterini atla
    movb     (%rbx), %al
    subb     $48, %al            # '0' çıkar
    movzbq   %al, %rax
    movl     %eax, 4(%rcx, %r11)  # Burst kaydet (offset 4)
    movl     %eax, 12(%rcx, %r11) # Remaining kaydet (offset 12)
    incq     %rbx                # Rakamı geç

    # --- FCFS KONTROLÜ ---
    cmpq     $2, %r14
    jne      _finish_process

    # 4. ARRIVAL TIME OKU
    incq     %rbx                # '-' karakterini atla
    movb     (%rbx), %al
    subb     $48, %al
    movzbq   %al, %rax
    movl     %eax, 8(%rcx, %r11)  # Arrival kaydet (offset 8)
    incq     %rbx                # Rakamı geç

_finish_process:
    incq     %rdi                # Bir sonraki sürece geç
    jmp      _parse_loop

_skip_space:
    incq     %rbx
    jmp      _parse_loop

_simulation_start:
    movl     %edi, process_count(%rip)

    cmpq     $1, %r15
    je       _run_fcfs

_run_fcfs:
    movl     $0, current_time(%rip)
    movq     $0, %r13            # output_buf index
    movq     $-1, %r14           # çalışan process index
    movq     $0, %r15            # biten process sayısı

fcfs_simulation:
    movl     process_count(%rip), %r8d
    movq     %r15, %rax
    cmpq     %rax, %r8           # process_count == biten
    je       fcfs_output
    
    cmpq     $-1, %r14
    jne      fcfs_run_current
    
    movq     $999999, %r9        # min_arrival
    movq     $-1, %r10           # selected_index
    movq     $0, %r11            # i = 0
    
fcfs_select_loop:
    movq     %r11, %rax
    cmpq     %rax, %r8
    je       fcfs_select_done
    
    # 16 byte offset hesapla
    movq     %r11, %rdx
    shlq     $4, %rdx
    lea      proc_buf(%rip), %rcx
    
    movl     12(%rcx, %rdx), %eax # remaining
    cmpl     $0, %eax
    jle      fcfs_select_next
    
    movl     8(%rcx, %rdx), %eax  # arrival
    movl     current_time(%rip), %ebx
    cmpl     %ebx, %eax
    jg       fcfs_select_next
    
    cmpq     %rax, %r9
    jle      fcfs_select_next
    
    movq     %rax, %r9
    movq     %r11, %r10
    
fcfs_select_next:
    incq     %r11
    jmp      fcfs_select_loop
    
fcfs_select_done:
    cmpq     $-1, %r10
    je       fcfs_idle_cycle
    movq     %r10, %r14
    
fcfs_run_current:
    movq     %r14, %rdx
    shlq     $4, %rdx
    lea      proc_buf(%rip), %rcx
    movb     (%rcx, %rdx), %al    # ID oku
    
    lea      output_buf(%rip), %rcx
    movb     %al, (%rcx, %r13)    # Output'a yaz
    incq     %r13
    
    # remaining azalt
    movq     %r14, %rdx
    shlq     $4, %rdx
    lea      proc_buf(%rip), %rcx
    movl     12(%rcx, %rdx), %eax
    decl     %eax
    movl     %eax, 12(%rcx, %rdx)
    
    cmpl     $0, %eax
    jne      fcfs_increment_time
    
    incq     %r15
    movq     $-1, %r14
    jmp      fcfs_increment_time

fcfs_idle_cycle:
    lea      output_buf(%rip), %rcx
    movb     $88, (%rcx, %r13)    # 'X'
    incq     %r13

fcfs_increment_time:
    incl     current_time(%rip)
    jmp      fcfs_simulation

fcfs_output:
    lea      output_buf(%rip), %rcx
    movb     $10, (%rcx, %r13)    # '\n'
    incq     %r13
    
    movq     $1, %rax
    movq     $1, %rdi
    lea      output_buf(%rip), %rsi
    movq     %r13, %rdx
    syscall
    
    jmp      .exit

.exit:
    movq     $60, %rax
    xorq     %rdi, %rdi
    syscall