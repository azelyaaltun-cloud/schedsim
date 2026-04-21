.section .bss
input_buf:      .space 256
output_buf:     .space 1024
temp_buf:       .space 256
proc_buf:       .space 160
process_count:  .space 4
current_time:   .space 4

# Round Robin helpers (optional)
rr_queue:       .space 64
rr_head:        .space 4
rr_tail:        .space 4

.section .data
newline:        .asciz "\n"

.section .text
.global _start

_start:
    # READ INPUT
    mov     $0, %rax
    mov     $0, %rdi
    lea     input_buf(%rip), %rsi
    mov     $256, %rdx
    syscall

    lea     input_buf(%rip), %rbx

    # FCFS Kontrolü
    cmpb    $'F', (%rbx)
    je      _handle_fcfs

_handle_fcfs:

    movq $1, %r15 # ID: 1

    movq $2, %r14 # 2 Sayı oku: Burst ve Arrival

    add $5, %rbx # "FCFS " atla

    jmp _common_parse        

    

    
_common_parse:
    xor     %rdi, %rdi          # rdi = 0 (Süreç sayacı)

_parse_loop:
    # 1. BİTİŞ KONTROLÜ
    movb    (%rbx), %al
    cmpb    $10, %al             # '\n' (Enter)
    je      _simulation_start
    cmpb    $0, %al              # Null
    je      _simulation_start
    cmpb    $' ', %al            # Boşluk
    je      _skip_space

    # 2. PROCESS ID KAYDET (A, B...)
    movb    %al, proc_buf(%rip, %rdi, 16)
    inc     %rbx                 # Harfi geç ('A'yı geçtik, imleç '-' üzerinde veya değil)

    # 3. BURST TIME OKU (Her zaman var)
    inc     %rbx                 # '-' karakterini atla
    movb    (%rbx), %al
    subb    $'0', %al           
    movzbl  %al, %eax
    movl    %eax, 4+proc_buf(%rip, %rdi, 16)    # Burst kaydet
    movl    %eax, 12+proc_buf(%rip, %rdi, 16)   # Remaining kaydet
    inc     %rbx                 # Rakamı geç ('3'ü geçtik)

    # --- BURASI KRİTİK: FCFS ise devam et, değilse atla ---
    cmpq    $2, %r14             # FCFS için r14'ü 2 yapmıştık
    jne     _finish_process      # Eğer 2 değilse (SJF ise) Arrival okuma, bitir

    # 4. ARRIVAL TIME OKU (Sadece FCFS ve gerekirse RR/PF için)
    inc     %rbx                 # '-' karakterini atla
    movb    (%rbx), %al
    subb    $'0', %al
    movzbl  %al, %eax
    movl    %eax, 8+proc_buf(%rip, %rdi, 16)    # Arrival kaydet
    inc     %rbx                 # Rakamı geç ('1'i geçtik)

_finish_process:
    inc     %rdi                 # Bir sonraki sürece hazırlan
    # Şu an imleç boşluğun üzerinde olabilir, döngü başına dönünce boşluk kontrolü yapılacak
    jmp     _parse_loop

    

_skip_space:
    inc     %rbx
    jmp     _parse_loop

_simulation_start:
    movl    %edi, process_count(%rip)  # Toplam süreci kaydet

    cmpq    $1, %r15                   # r15'e 1 demiştik
    je      _run_fcfs

_run_fcfs:
    jmp     .exit

##################################
# EXIT SYSCALL
##################################
.exit:
    mov     $60, %rax
    xor     %rdi, %rdi
    syscall