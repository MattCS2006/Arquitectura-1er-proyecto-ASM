includelib kernel32.lib
ExitProcess proto

.data
    a    dd ?
    b    dd ?
    c db 3,"202"
    d db 3,"139"
    mcm  dd ?
    ascii_mcm db 64,"x" 

.code
main PROC

   ;validar overflow de a
   lea R8,c; Pone el largo de la hilera en el stack
   mov R9b,byte ptr [R8]
   sub RSP,1
   mov [RSP],R9b
   add R8,1; Pone la direccion de la hilera en el stack
   push R8
   sub RSP,1; Abre espacio para el return value

   call Validar_OF

   pop R8; Extraer bandera de overflow
   add rsp,9

   cmp R8,1; Validar bandera de overflow
   je OF

   ;ahora para b

   lea R8,d; Pone el largo de la hilera en el stack
   mov R9b,byte ptr [R8]
   sub RSP,1
   mov [RSP],R9b
   add R8,1; Pone la direccion de la hilera en el stack
   push R8
   sub RSP,1; Abre espacio para el return value

   call Validar_OF

   pop R8; Extraer bandera de overflow
   add rsp,9

   cmp R8,1; Validar bandera de overflow
   je OF

   ; CONVERTIR C (ASCII) A BINARIO
    lea R8, c         ; direccion de la hilera C
    xor R9d, R9d         ; limpiar R9d
    mov R9b, byte ptr [R8] ; copiar byte sin signo a los 8 bits bajos
    push r9           ; longitud
    add R8, 1         ; puntero al primer caracter
    push R8           ; direccion de la hilera
    sub rsp, 8        ; espacio para return value (DWORD)

    call _ASCII_BIN   ; llama a la funcion de conversion

    xor eax, eax;            ; limpiar eax
    mov eax, dword ptr [rsp] ; Resultado entero de c en eax
    mov a, eax               ; Guardarlo en 'a' (variable global)

    add rsp, 16              ; limpiar stack frame (4+8+4)

    ; CONVERTIR D (ASCII) A BINARIO
    lea R8, d            ; direccion de la hilera D
    xor R9d, R9d         ; limpiar R9d
    mov R9b, byte ptr [R8] ; copiar byte sin signo a los 8 bits bajos
    push R9                ; longitud
    add R8, 1              ; puntero al primer caracter
    push R8                ; direccion de la hilera    
    sub rsp, 8             ; espacio para return value (DWORD)

    call _ASCII_BIN        ; llama a la funcion de conversion

    xor eax, eax;          ; limpiar eax
    mov eax, dword ptr [rsp] ; Resultado entero de d en eax
    mov b, eax             ; Guardarlo en 'b' (variable global)

    add rsp, 16            ; limpiar stack frame (4+8+4)

   ; Convertimos a 64 bits Y HACEMOS MCD
   mov eax, a
   movsxd rcx, eax; rcx <= a convertido a 64 bits

   mov eax, b
   movsxd rdx, eax; rdx <= b convertido a 64 bits

   ; Preparamos la pila (stack frame)
   sub rsp, 24          ; Reservamos espacio para el stack frame, Los otros +8 los a?ade el propio modulo para guardar el return address
   ;ACA TODAVIA NO ENTRA EL RETURN ADDRESS POR ESO ES QUE SE PONE +8 Y +16 AUNQUE EL STACK FRAME YA DENTRO ES +16 (para b) Y +24 (para a)
   mov qword ptr [rsp+16], rcx; Guarda a (64 bits) en [rsp+16] para pasarlo como parametro para el modulo
   mov qword ptr [rsp+8], rdx; Guarda b (64 bits) en [rsp+8] para pasarlo como parametro para el modulo

   call _MCD

   mov eax, dword ptr [rsp]; Recupera el resultado que esta en el top de la pila (ya que ya se quito del top el return address)
   xor ebx, ebx;
   mov ebx, eax; Metemos el resultado en mcd
   add rsp, 24; Limpiamos la pila

   ;AHORA TOCA HACER EL PROCESO PARA MCM
   mov eax, a
   movsxd rcx, eax; rcx <= a convertido a 64 bits

   mov eax, b
   movsxd rdx, eax; rdx <= b convertido a 64 bits

   mov eax, ebx
   movsxd r8, eax; r8 <= mcd convertido a 64 bits

   sub rsp, 32; Reservamos espacio para los par?metros



   mov qword ptr [rsp+24], rcx; [rsp+24] <= a
   mov qword ptr [rsp+16], rdx; [rsp+16] <= b
   mov qword ptr [rsp+8], r8; [rsp+8]   <= mcd

   call _MCM

   mov eax, dword ptr [rsp]; Recupera el resultado que esta en el top de la pila (ya que ya se quito del top el return address)
   mov mcm, eax            ; Metemos el resultado en mcm
   add rsp, 32             ; Limpiamos la pila

   ; Conversion del resultado MCM a ASCII en formato [longitud][caracteres]
    lea r8, ascii_mcm     ; direccion de la hilera
    add r8, 1             ; saltarse el primer byte de longitud
    push r8               ; direccion donde se guardaran los caracteres

    mov eax, mcm          ; numero a convertir
    push rax              ; resultado de la conversion

    call _BIN_ASCII       ; llamada a la conversion, nota: deja la longitud en ascii_mcm[0]

    add rsp, 16           ; limpiar stack (2 pushes de 8 bytes)

   call ExitProcess

   OF:;En caso de overflow, se devuelve "OVERFLOW como salida"
    mov r8, 6291331069371569743; equivale a "WOLFREVO" pero como es little endian queda "OVERFLOW"
    mov qword ptr [ascii_mcm], r8; "Lo metemos en el registro de resultado en MCM"
    call ExitProcess
main ENDP
;-------------------------------------------------------------
_MCD PROC
; Stack Frame:
; (ret.addr.): +0
; (ret.val.):  +8 (8 bytes)
; (b):           +16 (8 bytes)
; (a):           +24 (8 bytes) (32 bits)
   ; Convertimos a y b a 32 bits
   mov ecx, dword ptr [rsp+24]; ecx <- a 
   mov edx, dword ptr [rsp+16]; edx <- b 

   cmp edx, 0;Evita errores por division por 0 en caso que b = 0
   je fin_ciclo_MCD; Si b = 0 no tiene sentido hacer el mcd

ciclo_MCD:                     
   mov eax, ecx; eax = a
   mov ecx, edx; ecx = b

   xor edx, edx; limpiar edx antes de dividir porque queda el residuo
   div ecx; eax divido entre ecx. El cociente queda en el registro rax parte inferior de 32 bits, residuo en rdx lo mismo

   cmp edx, 0 ;Si el residuo es = 0 euclides dice de saltar
   je fin_ciclo_MCD ;Salta al final
   jmp ciclo_MCD ;Se devuelve al inicio del ciclo

fin_ciclo_MCD:
   mov eax, ecx                 ; Resultado final en eax (32 bits)
   mov [rsp+8], eax
   ret
_MCD ENDP
;-------------------------------------------------------------
_MCM PROC
;Stack Frame:
;(ret.addr.): +0
;(ret.val.): +8
;(mcd): +16
;(b): +24
;(a): +32
    ; Cargar parametros como 32 bits "Convertidos"
    mov eax, dword ptr [rsp+32]; EAX <= a
    mov ebx, dword ptr [rsp+24]; EBX <= b
    mov ecx, dword ptr [rsp+16]; ECX <= MCD

    ;a*b para luego dividirlo por mcd
    mul ebx; como a esta en eax y mul agarra siempre eax * parametro dado es a*b y queda en a, equivale a un a=a*b
    jo fin_overflow
    div ecx; lo mismo que la multiplicacion que quedo en eax, se divide por ecx donde esta mcd
    mov [rsp+8], eax;lo ponemos en el espacio de return address
    ret
    fin_overflow:
        mov r8, 6291331069371569743; equivale a "WOLFREVO" pero como es little endian queda "OVERFLOW"
        mov qword ptr [ascii_mcm], r8; "Lo metemos en el registro de resultado en MCM"
        call ExitProcess
_MCM ENDP
;-------------------------------------------------------------
Validar_OF PROC
;Stack Frame:
;(ret.addr.): +0
;(ret.val.): +8
;direccion_hilera: +9
;largo_hilera: +17

   mov R8b,[RSP+17]
   cmp R8b,10
   jl NOT_OF; Si son menos de 10 digitos no puede dar overflow
   jg OF; Si son mas de 10 digitos va a dar overflow

   mov R8,[RSP+9]; Se carga el primer digito de la hilera
   mov R9b,byte ptr [R8]
   cmp R9b,50
   jl NOT_OF; Si el primer digito en ASCII es menor que dos no puede dar OF
   jg OF; Si es mayor da OF

   add R8b,1;Se carga el digito 2
   mov R9b,byte ptr [R8]
   cmp R9b,49; Comparacion para digito 2
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 3
   mov R9b,byte ptr [R8]
   cmp R9b,52; Comparacion para digito 3
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 4
   mov R9b,byte ptr [R8]
   cmp R9b,55; Comparacion para digito 4
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 5
   mov R9b,byte ptr [R8]
   cmp R9b,52; Comparacion para digito 5
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 6
   mov R9b,byte ptr [R8]
   cmp R9b,56; Comparacion para digito 6
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 7
   mov R9b,byte ptr [R8]
   cmp R9b,51; Comparacion para digito 7
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 8
   mov R9b,byte ptr [R8]
   cmp R9b,54; Comparacion para digito 8
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 9
   mov R9b,byte ptr [R8]
   cmp R9b,52; Comparacion para digito 9
   jl NOT_OF
   jg OF

   add R8b,1;Se carga el digito 10
   mov R9b,byte ptr [R8]
   cmp R9b,55; Comparacion para digito 10
   jg OF
   ;Si todos los d?gitos calzan con 2^31-1 o la hilera es menor que este entonces no da OF

   NOT_OF:; Poner 0 en el return value como booleano en false y volver de la funcion
      mov R8,0
      mov [RSP+8],R8
      ret

   OF:; Poner 1 en el return value como booleano en true y volver de la funcion
      mov R8,1
      mov [RSP+8],R8
      ret
Validar_OF ENDP



;-------------------------------------------------------------
_ASCII_BIN PROC
; (ret.addr.): +0
; (ret.val.):  +8
; (direccion): +16
; (longitud):  +24

    mov rsi, [rsp+16]      ; puntero a los caracteres
    mov rcx, [rsp+24]      ; longitud de la hilera

    xor rax, rax           ; acumulador, inicia en 0
    xor rbx, rbx           ; digito temporal

ascii_loop:
    cmp rcx, 0            
    je fin_ascii           ; si ya no hay mas digitos, salir

    mov bl, byte ptr [rsi] ; cargar caracter
    sub bl, '0'            ; convertir ASCII a numero
    imul eax, eax, 10      ; resultado *= 10
    add eax, ebx           ; resultado += digito

    inc rsi                ; mover puntero
    dec rcx                ; decrementar longitud      
    jmp ascii_loop         ; continuar

fin_ascii:
    mov [rsp+8], eax       ; guardar resultado
    ret                    ; volver
_ASCII_BIN ENDP
;-------------------------------------------------------------
_BIN_ASCII PROC
; Stack Frame:
; [rsp+0]  = return address
; [rsp+8]  = n?mero a convertir (qword)
; [rsp+16] = direcci?n de salida (qword)

    mov rsi, [rsp+16]           ; direccion donde escribir los digitos
    mov eax, dword ptr [rsp+8]  ; numero a convertir

    xor rcx, rcx                ; contador para los digitos, inicia en 0
    lea rdi, [rsp-32]           ; buffer temporal (en reversa)
    mov rbx, 10                 ; divisor base 10

reverse_loop:
    xor rdx, rdx                ; limpiar el residuo
    div rbx                     ; EAX / 10
    add dl, '0'                 ; convertir a ASCII
    dec rdi                     ; guardar en el buffer temporal
    mov [rdi], dl               ; guardar digito
    inc rcx                     ; incrementar contador
    test eax, eax               ; si EAX == 0, salir
    jnz reverse_loop            ; continuar

    ; guardar longitud
    mov al, cl                  ; longitud
    mov [rsi-1], al             ; longitud justo antes de la hilera

    ; copiar al buffer de salida
    mov rbx, rcx
copy_loop:
    cmp rbx, 0                  ; si no hay mas digitos, salir
    je fin_ascii_copy
    mov al, byte ptr [rdi]      ; cargar el siguiente digito
    mov [rsi], al               ; escribir en la salida
    inc rsi                     ; mover puntero de salida
    inc rdi                     ; mover puntero de buffer
    dec rbx                     ; decrementar contador
    jmp copy_loop               ; continuar

fin_ascii_copy:
    ret                         ; volver
_BIN_ASCII ENDP

END
