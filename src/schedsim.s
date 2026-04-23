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

   # 2. ALGORITMA TESPİTİ
    cmpb    $70, (%rbx)         # 'F'
    je      _handle_fcfs
    cmpb    $83, (%rbx)         # 'S'
    je      _check_s_type       # hangi 'S'?
    jmp     .exit

_check_s_type:
    cmpb    $82, 1(%rbx)        # S'den sonra 'R' var mı?
    je      _handle_srtf        # varsa SRTF
    jmp     _handle_sjf         # yoksa SJF

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

_handle_srtf:
    movq    $3, %r15            # Algoritma ID: 3
    movq    $2, %r14            # 2 Sayı oku (Burst-Arrival)
    addq    $5, %rbx
    jmp     _common_parse

_common_parse:
    xorq    %rdi, %rdi          # Process sayacı
# Çok basamaklı sayıları okumak için sayı okuma döngüsü tasarladım. Karakter alıp geçmek yerine 0-9 arası sayı gördükçe okumaya devam ediyor.
_parse_loop:
    movb    (%rbx), %al
    cmpb    $10, %al            # '\n'
    je      _simulation_start
    cmpb    $0, %al             # Null
    je      _simulation_start
    cmpb    $32, %al            # Boşluk
    je      _skip_space

    # Process id'yi kaydet
    movq    %rdi, %r11
    shlq    $4, %r11            # r11 = rdi * 16
    lea     proc_buf(%rip), %rcx
    movb    %al, (%rcx, %r11)   # id'yi  yaz
    incq    %rbx                # harfi geç

    # Çok basamaklı burst time okuma
    incq    %rbx                # '-' karakterini atla
    xorq    %rax, %rax          # sonucu sıfırla
_read_burst_loop:
    movzbq  (%rbx), %rdx        # karakteri rdx'e al
    cmpb    $48, %dl            # 0' dan küçük mü?
    jl      _read_burst_done
    cmpb    $57, %dl            # 9' dan büyük mü?
    jg      _read_burst_done

    # Yeni rakam okuduğunda eskisini 10 ile çarpıp yenisini ekliyor.
    subq    $48, %rdx           # karakteri rakama çevir
    imulq   $10, %rax
    addq    %rdx, %rax
    incq    %rbx                # imleci ilerlet
    jmp     _read_burst_loop
    
_read_burst_done:
    movl    %eax, 4(%rcx, %r11)   # burst'ü kaydet
    movl    %eax, 12(%rcx, %r11)  # remaining'e burst'ü yaz

    # FCFS ise arrival oku (çok basamaklı)
    cmpq    $2, %r14
    jne     _finish_process
    incq    %rbx                # '-' karakterini atla
    xorq    %rax, %rax          # sonucu sıfırla

_read_arrival_loop:
    movzbq  (%rbx), %rdx
    cmpb    $48, %dl
    jl      _read_arrival_done
    cmpb    $57, %dl
    jg      _read_arrival_done

    subq    $48, %rdx
    imulq   $10, %rax
    addq    %rdx, %rax
    incq    %rbx
    jmp     _read_arrival_loop

_read_arrival_done:
    movl    %eax, 8(%rcx, %r11)   # arrival'ı kaydet

_finish_process:
    incq    %rdi                # bir sonraki sürece hazırlan
    jmp     _parse_loop

_skip_space:
    incq    %rbx
    jmp     _parse_loop

_simulation_start:
    movl    %edi, process_count(%rip)
    cmpq    $1, %r15
    je      _run_fcfs
    cmpq    $2, %r15
    je      _run_sjf
    cmpq    $3, %r15
    je      _run_srtf
    jmp     .exit

# FCFS

_run_fcfs:
    movl    $0, current_time(%rip)
    movq    $0, %r13            # output_buf index
    movq    $-1, %r14           # çalışan process index
    movq    $0, %r15            # biten process sayısı

fcfs_simulation:
    movl    process_count(%rip), %r8d
    cmpq    %r15, %r8           # process_count == biten
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

    movl    12(%rcx, %rdx), %eax   # remaining
    cmpl    $0, %eax
    jle     fcfs_select_next

    movl    8(%rcx, %rdx), %eax    # arrival
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

    lea     output_buf(%rip), %r12
    movb    %al, (%r12, %r13)
    incq    %r13

    decl    12(%rcx, %rdx)
    cmpl    $0, 12(%rcx, %rdx)
    jne     fcfs_tick
    incq    %r15
    movq    $-1, %r14

fcfs_tick:
    incl    current_time(%rip)
    jmp     fcfs_simulation

fcfs_idle:
    lea     output_buf(%rip), %r12
    movb    $88, (%r12, %r13)       # 'X' yaz
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

    movl    12(%rcx, %rdx), %eax   # remaining
    cmpl    $0, %eax
    jle     sjf_select_next

    movl    4(%rcx, %rdx), %eax    # Burst Time (SJF kıstası)
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

    lea     output_buf(%rip), %r12
    movb    %al, (%r12, %r13)
    incq    %r13

    decl    12(%rcx, %rdx)
    cmpl    $0, 12(%rcx, %rdx)
    jne     sjf_tick
    incq    %r15
    movq    $-1, %r14

sjf_tick:
    incl    current_time(%rip)
    jmp     sjf_simulation

# SRTF
_run_srtf:
    movl    $0, current_time(%rip)
    movq    $0, %r13            # output_buf index
    movq    $0, %r15            # biten process sayısı

srtf_simulation:
    movl    process_count(%rip), %r8d
    cmpq    %r15, %r8           # hepsi bitti mi?
    je      _output_final

    # Preemption (her saniye seçim yap)
    movq    $999999, %r9        # min_remaining_time
    movq    $-1, %r10           # selected_index
    movq    $0, %r11            # i

srtf_select_loop:
    cmpq    %r11, %r8
    je      srtf_select_done

    movq    %r11, %rdx
    shlq    $4, %rdx            # 16 byte offset
    lea     proc_buf(%rip), %rcx

    # kalan süre > 0 mı?
    movl    12(%rcx, %rdx), %eax
    cmpl    $0, %eax
    jle     srtf_select_next

    # geldi mi? (yani Arrival <= CurrentTime mı)
    movl    8(%rcx, %rdx), %ebx
    cmpl    current_time(%rip), %ebx
    jg      srtf_select_next

    # kalan süresi daha mı kısa?
    cmpl    %eax, %r9d
    jle     srtf_select_next

    movl    %eax, %r9d          # yeni minimum kalan süre
    movq    %r11, %r10          # yeni seçilen index

srtf_select_next:
    incq    %r11
    jmp     srtf_select_loop

srtf_select_done:
    cmpq    $-1, %r10
    je      srtf_idle

    movq    %r10, %rdx
    shlq    $4, %rdx
    lea     proc_buf(%rip), %rcx
    movb    (%rcx, %rdx), %al

    lea     output_buf(%rip), %r12
    movb    %al, (%r12, %r13)
    incq    %r13

    decl    12(%rcx, %rdx)
    cmpl    $0, 12(%rcx, %rdx)
    jne     srtf_tick
    incq    %r15

srtf_tick:
    incl    current_time(%rip)
    jmp     srtf_simulation

srtf_idle:
    lea     output_buf(%rip), %r12
    movb    $88, (%r12, %r13)
    incq    %r13
    incl    current_time(%rip)
    jmp     srtf_simulation

# ÇIKTI
_output_final:
    lea     output_buf(%rip), %r12
    movb    $10, (%r12, %r13)
    incq    %r13

    movq    $1, %rax
    movq    $1, %rdi
    lea     output_buf(%rip), %rsi
    movq    %r13, %rdx
    syscall

.exit:
    movq    $60, %rax
    xorq    %rdi, %rdi
    syscall