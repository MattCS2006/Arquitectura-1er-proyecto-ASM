.MODEL SMALL
.STACK 100h

.DATA
msg DB "Hello, Assembly World!$"

.CODE
main PROC
    mov ax, @data
    mov ds, ax

    mov ah, 9
    lea dx, msg
    int 21h

    mov ah, 4Ch
    int 21h
main ENDP
END main
