; Programa en ensamblador 80x86 para MASM
; Solo contiene las funciones de conversi�n ASCII a binario y binario a ASCII

.386
.MODEL FLAT, STDCALL
OPTION CASEMAP:NONE
.STACK 4096

; Incluir bibliotecas de Windows
includelib kernel32.lib
includelib user32.lib

; Declarar funciones de Windows que vamos a usar
ExitProcess PROTO, dwExitCode:DWORD
MessageBoxA PROTO, hWnd:DWORD, lpText:DWORD, lpCaption:DWORD, uType:DWORD

.DATA
    ; T�tulos y mensajes
    caption_ascii_to_bin DB "Resultado de ASCII a Binario", 0
    caption_bin_to_ascii DB "Resultado de Binario a ASCII", 0
    
    ; N�meros de entrada en formato ASCII (ejemplos)
    num1_ascii DB "2345253", 0       ; Primer n�mero en ASCII
    num2_ascii DB "56", 0       ; Segundo n�mero en ASCII

    ; Almacenamiento para representaciones binarias
    num1_bin DD 0               ; Primer n�mero en binario (32 bits)
    num2_bin DD 0               ; Segundo n�mero en binario (32 bits)

    ; Almacenamiento para resultados
    result_bin DD 0             ; Resultado en binario
    result_ascii DB 100 DUP(0)  ; Resultado en ASCII (buffer para hasta 100 caracteres)
    binary_result_msg DB "El valor binario es: ", 0
    overflow_msg DB "overflow", 0 ; Mensaje de overflow
    
    ; Buffer para mensajes formateados
    msg_buffer DB 100 DUP(0)   ; Buffer para mensajes

.CODE
_main PROC
    ; El c�digo principal se a�adir� por otros miembros del equipo
    ; Este archivo solo contiene las dos funciones de conversi�n

    ; Ejemplo b�sico de uso:
    lea esi, num1_ascii        ; Cargar direcci�n de la cadena ASCII
    lea edi, num1_bin          ; Cargar direcci�n donde guardar el resultado binario
    call ascii_to_bin          ; Llamar a la funci�n de conversi�n
    
    ; Mostrar el resultado de la conversi�n ASCII a binario
    mov eax, num1_bin
    push eax                   ; Valor a mostrar
    lea eax, msg_buffer        ; Buffer de mensaje
    push eax
    call format_decimal_message ; Formatear mensaje con el n�mero
    
    ; Mostrar el resultado en una ventana
    invoke MessageBoxA, 0, ADDR msg_buffer, ADDR caption_ascii_to_bin, 0
    
    ; Ejemplo de conversi�n binario a ASCII:
    lea esi, num1_bin          ; Cargar direcci�n del n�mero binario
    lea edi, result_ascii      ; Cargar direcci�n donde guardar la cadena ASCII
    call bin_to_ascii          ; Llamar a la funci�n de conversi�n
    
    ; Mostrar el resultado en una ventana
    invoke MessageBoxA, 0, ADDR result_ascii, ADDR caption_bin_to_ascii, 0
    
    ; Salir del programa
    invoke ExitProcess, 0
_main ENDP

;---------------------------------------------------------------
; format_decimal_message - Formatea un mensaje con un valor decimal
;
; Entrada:
;   [ESP+8] = valor DWORD a mostrar
;   [ESP+4] = puntero al buffer de destino
;---------------------------------------------------------------
format_decimal_message PROC
    push ebp
    mov ebp, esp
    
    mov edi, [ebp+8]     ; Buffer de destino
    mov ecx, [ebp+12]    ; Valor a mostrar
    
    ; Copiar "El valor binario es: " al buffer
    lea esi, binary_result_msg
copy_msg_loop:
    mov al, [esi]
    test al, al
    jz done_copying
    mov [edi], al
    inc esi
    inc edi
    jmp copy_msg_loop
    
done_copying:
    ; Convertir el valor num�rico a ASCII directamente en el buffer
    mov eax, ecx
    
    ; Caso especial para el cero
    test eax, eax
    jnz convert_digits_inline
    
    mov BYTE PTR [edi], '0'
    inc edi
    jmp add_null_terminator
    
convert_digits_inline:
    ; Primero encontrar cu�ntos d�gitos hay y almacenarlos en la pila
    xor ecx, ecx         ; Contador de d�gitos
    mov ebx, 10          ; Divisor
    
digit_count_loop:
    xor edx, edx         ; Limpiar EDX para div
    div ebx              ; EDX:EAX / 10, cociente en EAX, resto en EDX
    push edx             ; Guardar d�gito en la pila
    inc ecx              ; Incrementar contador
    test eax, eax        ; �Hay m�s d�gitos?
    jnz digit_count_loop ; Si hay, continuar
    
    ; Ahora sacar los d�gitos y escribirlos al buffer
write_digits_loop:
    pop eax              ; Obtener d�gito
    add al, '0'          ; Convertir a ASCII
    mov [edi], al        ; Escribir al buffer
    inc edi              ; Siguiente posici�n
    loop write_digits_loop ; Decrementar contador y continuar
    
add_null_terminator:
    mov BYTE PTR [edi], 0 ; A�adir terminador nulo
    
    mov esp, ebp
    pop ebp
    ret 8                ; Limpiar 8 bytes de la pila (2 par�metros)
format_decimal_message ENDP

;---------------------------------------------------------------
; ascii_to_bin - Convierte una cadena ASCII a un n�mero binario de 32 bits
; 
; Entrada:
;   ESI = puntero a la cadena ASCII
;   EDI = puntero a donde almacenar el resultado binario
;
; Salida:
;   [EDI] = n�mero binario de 32 bits
;   Carry flag activado si la conversi�n result� en overflow
;
; Preserva: todos los registros excepto EAX, ECX, EDX
;---------------------------------------------------------------
ascii_to_bin PROC
    push ebp                    ; Guardar puntero base
    mov ebp, esp                ; Configurar marco de pila
    push ebx                    ; Guardar registros utilizados
    
    xor eax, eax                ; Inicializar resultado a 0
    xor ecx, ecx                ; Inicializar contador de d�gitos
    
bucle_conversion:
    movzx ebx, BYTE PTR [esi]   ; Cargar siguiente car�cter
    test bl, bl                 ; Verificar si es terminador nulo
    jz conversion_completa      ; Si es cero, hemos terminado
    
    sub bl, '0'                 ; Convertir ASCII a d�gito real
    
    ; Verificar si es un d�gito v�lido (0-9)
    cmp bl, 0
    jl caracter_invalido
    cmp bl, 9
    jg caracter_invalido
    
    ; Verificar overflow antes de multiplicar por 10
    ; Si EAX > 429496729, multiplicar por 10 causar� overflow en 32 bits
    cmp eax, 429496729
    ja error_overflow
    
    ; Tambi�n verificar si EAX = 429496729 y siguiente d�gito > 5
    cmp eax, 429496729
    jne multiplicar_por_diez
    cmp bl, 5
    ja error_overflow
    
multiplicar_por_diez:
    ; Multiplicar resultado actual por 10
    imul eax, 10
    jo error_overflow           ; Saltar si ocurri� overflow
    
    ; A�adir nuevo d�gito
    movzx ebx, bl               ; Extender BL a EBX con ceros
    add eax, ebx
    jc error_overflow           ; Saltar si ocurri� carry
    
    inc esi                     ; Mover al siguiente car�cter
    jmp bucle_conversion
    
caracter_invalido:
    ; Manejar car�cter inv�lido
    xor eax, eax                ; Devolver 0 para entrada inv�lida
    stc                         ; Establecer carry flag para indicar error
    jmp salir_conversion
    
error_overflow:
    stc                         ; Establecer carry flag para indicar overflow
    jmp salir_conversion
    
conversion_completa:
    mov [edi], eax              ; Almacenar resultado de 32 bits
    clc                         ; Limpiar carry flag - conversi�n exitosa
    
salir_conversion:
    pop ebx                     ; Restaurar registros
    mov esp, ebp                ; Restaurar puntero de pila
    pop ebp                     ; Restaurar puntero base
    ret
ascii_to_bin ENDP

;---------------------------------------------------------------
; bin_to_ascii - Convierte un n�mero binario de 32 bits a cadena ASCII
; 
; Entrada:
;   ESI = puntero al n�mero binario de 32 bits
;   EDI = puntero al buffer para el resultado ASCII
;
; Salida:
;   [EDI] = cadena ASCII terminada en nulo
;
; Preserva: todos los registros excepto EAX, ECX, EDX, EDI
;---------------------------------------------------------------
bin_to_ascii PROC
    push ebp                    ; Guardar puntero base
    mov ebp, esp                ; Configurar marco de pila
    push ebx                    ; Guardar registros utilizados
    
    mov eax, [esi]              ; Cargar valor de 32 bits
    mov ebx, edi                ; Guardar puntero de destino
    
    ; Manejar caso especial para cero
    test eax, eax
    jnz convertir_digitos
    
    mov BYTE PTR [edi], '0'     ; Escribir '0'
    inc edi
    jmp agregar_terminador_nulo
    
convertir_digitos:
    ; Primera pasada: convertir d�gitos y empujarlos en la pila
    xor ecx, ecx                ; Inicializar contador de d�gitos
    
bucle_digitos:
    xor edx, edx                ; Limpiar parte alta del dividendo
    mov ebx, 10                 ; Divisor (10 para decimal)
    div ebx                     ; Dividir EDX:EAX por 10, resto en EDX
    
    add dl, '0'                 ; Convertir resto a ASCII
    push edx                    ; Guardar d�gito en la pila
    inc ecx                     ; Incrementar contador de d�gitos
    
    test eax, eax               ; Verificar si el cociente es cero
    jnz bucle_digitos           ; Si no, continuar
    
    ; Segunda pasada: sacar d�gitos de la pila y escribir en el buffer
bucle_escritura:
    pop eax                     ; Obtener siguiente d�gito
    mov [edi], al               ; Escribir d�gito en el buffer
    inc edi                     ; Mover a la siguiente posici�n
    loop bucle_escritura        ; Decrementar ECX y continuar si no es cero
    
agregar_terminador_nulo:
    mov BYTE PTR [edi], 0       ; A�adir terminador nulo
    
    pop ebx                     ; Restaurar registros
    mov esp, ebp                ; Restaurar puntero de pila
    pop ebp                     ; Restaurar puntero base
    ret
bin_to_ascii ENDP

END _main
