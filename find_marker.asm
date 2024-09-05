;---------------------------------------------
; Author: Kornelia Błaszczuk
; Project: Finding marker (no. 3)
;---------------------------------------------

; BMP INFO
BMP_FORMAT      equ     19778   ; Id of BMP format
RESULT_S        equ     200

; Constants for BMP header offsets
HEIGHT_OFFSET   equ 22   ; Offset of height field in BMP header (in bytes)
WIDTH_OFFSET    equ 18   ; Offset of width field in BMP header (in bytes)

section .bss
    result_buffer:  resb    RESULT_S
    HEIGHT_VALUE    resd 1   ; Reserve space to store the height value
    WIDTH_VALUE     resd 1   ; Reserve space to store the width value
    PIXEL_ARRAY_SIZE resd 1  ; Reserve space to store the pixel array size
    BYTES_PER_ROW   resd  1  ; Reserve space to store bytes per row

section .text
    global  find_marker

find_marker:
    push    esi
    push    ebp
    mov     ebp,    esp

    ; Parameters:
    ; bitmap: [ebp+12]
    ; x_pos: [ebp+16]
    ; y_pos: [ebp+20]

.analyze_header:
    ; Analyze header -> checks if the file is in bmp format
    mov     eax,    DWORD[ebp+12]   ; eax -> file start
    mov     ax,     WORD[eax]       ; file header
    cmp     ax,     BMP_FORMAT      ; check if file is BMP format
    jne     .wrong_file_format

    ; Read the width and height from the BMP header
    mov     eax, DWORD[ebp+12]       ; Load the address of the BMP header
    add     eax, WIDTH_OFFSET        ; Offset to the width field
    mov     ebx, [eax]               ; Load the width value
    mov     [WIDTH_VALUE], ebx       ; Store the width value

    mov     eax, DWORD[ebp+12]       ; Load the address of the BMP header
    add     eax, HEIGHT_OFFSET       ; Offset to the height field
    movzx   ebx, WORD [eax]          ; Load the height value (using WORD to load 16 bits)
    mov     [HEIGHT_VALUE], ebx      ; Store the height value

    ; Calculate the bytes per row based on the width and bytes per pixel
    mov     eax, [WIDTH_VALUE]       ; Load the width value
    imul    eax, 3                    ; Multiply by bytes per pixel (assuming 24 bits per pixel)
    add     eax, 3                    ; Add 3 to round up to the nearest multiple of 4
    shr     eax, 2                    ; Divide by 4 to get the number of DWORDs (32-bit words)
    shl     eax, 2                    ; Multiply by 4 to get the number of bytes per row
    mov     [BYTES_PER_ROW], eax      ; Store the result as bytes per row

    ; Calculate the total size of the pixel array including row padding
    mov     eax, [BYTES_PER_ROW]     ; Load the bytes per row
    imul    eax, [HEIGHT_VALUE]      ; Multiply by the height
    mov     [PIXEL_ARRAY_SIZE], eax  ; Store the result as the total size of the pixel array

.get_variables:
    mov     eax,    DWORD[ebp+12]       ; eax -> file start
    add     eax,    DWORD[eax+10]       ; start of pixel array
    push    DWORD   eax                 ; Preserve start of the pixel array on stack
    mov     eax,    DWORD[ebp-4]
    mov     ebx,    [PIXEL_ARRAY_SIZE]
    add     eax,    ebx
    mov     DWORD[ebp-8],   eax

    sub     esp,    48

    mov     DWORD[ebp-44],      0
    mov     DWORD[ebp-16],      0               ; pixel color
    mov     DWORD[ebp-36],      result_buffer   ; result iterator
    mov     DWORD[ebp-56],      0
    ;   [ebp-4] -> pixel array start
    ;   [ebp-8] -> pixel array end
    ;   [ebp-12] -> point where arms cross
    ;   [ebp-16] -> current color
    ;   [ebp-20] -> thickness_height
    ;   [ebp-24] -> height
    ;   [ebp-28] -> width
    ;   [ebp-32] -> thickness_width
    ;   [ebp-36] -> result iterator
    ;   [ebp-40] -> pixel after marker
    ;   [ebp-44] -> store stage: so the get_pixel knows where to return

    ;   [ebp-48] -> first column iterator
    ;   [ebp-52] -> second height iterator
    ;   [ebp-56] -> counter for finden markers

.analyze_pixels:
    mov     esi,    DWORD[ebp-4]    ; array iterator
    jmp     .next_black

    .next_marker:
        mov     esi,    DWORD[ebp-40]
        jmp     .next_black

    ; stage 0
    .next_black:
        ; if end of pixel array -> end
        cmp     esi,    DWORD[ebp-8]
        jge     .find_marker_end
        mov     eax,    esi
        jmp     .get_pixel_color

    .next_black_continue:
        ; if not black go to next pixel
        cmp     DWORD[ebp-16],    0
        jne     .next

        mov     DWORD[ebp-12],  esi
        mov     DWORD[ebp-24],  3   ; height
        mov     DWORD[ebp-44],  1   ; stage

        jmp     .height

    .next:
        add     esi,    3
        jmp     .next_black

    ; stage 1
    .height:
        mov     eax,    esi
        mov     ebx,    [BYTES_PER_ROW] ; go row up
        add     eax,    ebx
        cmp     eax,    DWORD[ebp-8]    ; if end of pixel array -> end of count
        jge     .height_end

        jmp     .get_pixel_color

    .height_continue:
        cmp     DWORD[ebp-16],  0
        jne     .height_end

        add     DWORD[ebp-24],  3
        mov     ebx,    [BYTES_PER_ROW]
        add     esi,    ebx     ; row up
        jmp     .height

    .height_end:
        mov     DWORD[ebp-20],  3   ; thickness_height
        mov     DWORD[ebp-44],  2   ;stage
        jmp     .thick

    ; stage 2
    .thick:
        mov     eax,    esi
        add     eax,    3
        cmp     eax,    DWORD[ebp-8]    ; if end of pixel array -> end of count
        jge     .thick_end

        jmp     .get_pixel_color

    .thick_continue:
        cmp     DWORD[ebp-16],  0   ; if not black check next paramether
        jne     .thick_end

        add     DWORD[ebp-20],    3 ; stage
        add     esi,    3
        jmp     .thick

    .thick_end:
        mov     DWORD[ebp-28],    3 ; width
        mov     esi,    [ebp-12]    ; start from the point where the arms cross

        jmp     .width

    ; stage 3
    .width:
        ; checking if last pixel in row
        mov     eax,    esi
        mov     ebx,    [BYTES_PER_ROW]
        add   eax,  ebx             ; eax - address of the pixel
        sub   eax,  DWORD[ebp-4]    ; eax -= array start
        xor   edx,  edx             ; edx = 0
        mov   ecx,  ebx
        div   ecx

        mov     eax,    edx
        xor     edx,    edx
        mov     ecx,    3
        div     ecx
        mov     ebx,    [WIDTH_VALUE]
        add     ebx,    -1
        cmp     ebx,    eax     ; check if last in row (coords starts from 0)
        je      .check
        ;--------------------------

        mov     eax,    esi
        add     eax,    3
        cmp     eax,    DWORD[ebp-8]    ; check if end of pixel array
        jge     .check

        mov     DWORD[ebp-44],  3       ; stage
        jmp     .get_pixel_color

    .width_continue:
        cmp     DWORD[ebp-16],  0
        jne     .check

        add     DWORD[ebp-28],    3
        add     esi,    3
        jmp     .width

    .check:
        ; ebp-28 -> width
        ; ebp-24 -> height
        ; ebp-20 -> thickness_height

        mov     ecx,  esi
        add     ecx,    3
        mov     DWORD[ebp-40],  ecx

        mov     ecx,    DWORD[ebp-28]   ; width

        cmp     ecx,    DWORD[ebp-24]   ; cmp width and height
        jne     .go_to_next_marker

        cmp     ecx,    DWORD[ebp-20]   ; cmp width and thickness_height
        je      .go_to_next_marker

        mov     DWORD[ebp-32],  3   ; thickness_width

        sub     esi,    3   ; go to the last pixel in marker

        jmp     .thickness_width

    ; stage 4
    .thickness_width:
        mov     eax,    esi
        mov     ebx,    [BYTES_PER_ROW]
        add     eax,    ebx
        cmp     eax,    DWORD[ebp-8]
        jge     .thickness_width_end

        mov     DWORD[ebp-44],  4   ; stage
        jmp     .get_pixel_color

    .thickness_width_continue:
        cmp     DWORD[ebp-16],  0
        jne     .thickness_width_end

        add     DWORD[ebp-32],    3
        mov     ebx,    [BYTES_PER_ROW] ; go row up
        add     esi,    ebx
        jmp     .thickness_width

    .thickness_width_end:
        mov     esi,    DWORD[ebp-40]   ; pixel after marker
        jmp     .check_inside

    .check_inside:
        mov     esi,    DWORD[ebp-12]
        mov     edi,    DWORD[ebp-12] ; current column
        mov     DWORD[ebp-52],    3    ; width
        mov     DWORD[ebp-48],    3    ; height

        jmp     .loop_1

        ; stage 5
        .loop_1:
            mov     eax,    esi
            mov     ebx,    [BYTES_PER_ROW]
            add     eax,    ebx
            cmp     eax,    DWORD[ebp-8]
            jge     .next_loop

            mov     DWORD[ebp-44],  5   ; stage
            jmp     .get_pixel_color

        .loop_continue:
            cmp     DWORD[ebp-16],  0
            jne     .next_loop

            add     DWORD[ebp-48],    3 ; first iterator - column
            mov     ebx,    [BYTES_PER_ROW] ; row up
            add     esi,    ebx
            jmp     .loop_1

        .next_loop:
            add     edi,    3
            mov     esi,    edi
            add     DWORD[ebp-52],     3

            mov     ecx,    DWORD[ebp-48]
            cmp     ecx,     DWORD[ebp-24]  ; cmp height and counted length
            jne     .loop_end_incorrect

            mov     DWORD[ebp-48],     3

            mov     eax, DWORD[ebp-52]  ; second iterator height
            cmp     eax,     DWORD[ebp-20]  ; checks columns

            jg     .loop_2
            jmp     .loop_1

        ; stage 6
        .loop_2:
            mov     eax,    esi
            mov     ebx,    [BYTES_PER_ROW]
            add     eax,    ebx
            cmp     eax,    DWORD[ebp-8]
            jge     .next_loop_2

            mov     DWORD[ebp-44],  6   ; stage
            jmp     .get_pixel_color

        .loop_2_continue:
            cmp     DWORD[ebp-16],  0
            jne     .next_loop_2
            add     DWORD[ebp-48],    3
            mov     ebx,    [BYTES_PER_ROW]
            add     esi,    ebx

            jmp     .loop_2

        .next_loop_2:
            add     edi,    3
            mov     esi,    edi
            add     DWORD[ebp-52],     3

            mov     ecx,    DWORD[ebp-48]

            cmp     ecx,     DWORD[ebp-32]  ; cmp counted and thickness_width
            jne     .loop_end_incorrect

            mov     DWORD[ebp-48],     3

            mov eax, DWORD[ebp-52]

            cmp     eax,     DWORD[ebp-28]
            jge     .loop_end_correct
            jmp     .loop_2

        .loop_end_correct:
            mov     esi,    DWORD[ebp-40] ; if inside correct, check outside borders
            jmp     .check_outside

        .loop_end_incorrect:
            mov     esi,    DWORD[ebp-40]
            jmp     .go_to_next_marker

    .check_outside:
        ; [ebp-40] -> pixel after marker
        mov     DWORD [ebp-48],     3

        ; check if pixel (after width arm) is first in row
        mov     eax,    DWORD[ebp-40]
        mov     ebx,    [BYTES_PER_ROW]
        add   eax,  ebx   ; eax = address of the pixel
        sub   eax,  DWORD[ebp-4]    ; eax -= array start
        xor   edx,  edx             ; edx = 0 (for div to work correctly)
        mov   ecx,  ebx
        div   ecx

        mov     eax,    edx
        xor     edx,    edx
        mov     ecx,    3
        div     ecx
        mov     ebx,    0
        cmp     ebx,    eax
        je      .skip

        mov     ebx,    DWORD[ebp-32]
        mov     DWORD[ebp-52],  ebx
        add     DWORD[ebp-52],  6
        mov     ebx,    [BYTES_PER_ROW]   ; go row down
        sub     esi,    ebx

        cmp     esi,    DWORD[ebp-4]
        jl      .skip

        ; stage 7
        .border_1:
            mov     eax,    esi
            mov     ebx,    [BYTES_PER_ROW]
            add     eax,    ebx

            mov     DWORD[ebp-44],  7
            jmp     .get_pixel_color

        .border_1_continue:
            cmp     DWORD[ebp-16],  0
            je     .go_to_next_marker
            mov     ebx,    DWORD[ebp-52]
            cmp     DWORD[ebp-48],  ebx
            je      .border_1_end

            add     DWORD[ebp-48],  3 ; height of border after width
            mov     ebx,    [BYTES_PER_ROW]
            add     esi,    ebx
            jmp     .border_1

        .skip: ; skip border_1 if pixel after mark is first in row
            mov     esi,  DWORD[ebp-12]
            add     esi,    DWORD[ebp-32]
            jmp     .border_1_end

        .border_1_end:
            mov     esi,    DWORD[ebp-12]   ; goes to the point where arms cross
            add     esi,    DWORD[ebp-20]   ; we add to it thickness of height
            mov     ebx,    [BYTES_PER_ROW] ;  we go as many rows so we are at the white pixel where arms cross
            mov     ecx,    DWORD[ebp-32]
            imul    ebx,    ecx
            mov     DWORD[ebp-52],  ebx
            add     esi,    DWORD[ebp-52]

            mov     DWORD[ebp-48],  3
            mov     ebx,    DWORD[ebp-24]
            sub     ebx,    DWORD[ebp-32]
            mov     DWORD[ebp-52],  ebx
            add     DWORD[ebp-52],  3

            jmp     .border_2

        ; stage 8
        .border_2:
            mov     eax,    esi
            mov     ebx,    [BYTES_PER_ROW]
            add     eax,    ebx

            cmp     eax,    DWORD[ebp-8]
            jge     .border_2_end

            mov     DWORD[ebp-44],  8
            jmp     .get_pixel_color

        .border_2_continue:
            cmp     DWORD[ebp-16],  0
            je     .go_to_next_marker

            mov     ebx,    DWORD[ebp-52]
            cmp     DWORD[ebp-48], ebx
            je      .border_2_end
            add     DWORD[ebp-48],  3
            mov     ebx,    [BYTES_PER_ROW]
            add     esi,    ebx
            jmp     .border_2

        .border_2_end:
            mov     DWORD[ebp-48],  3
            mov     esi,    DWORD[ebp-12]
            add     esi,    -3
            mov     ebx,    [BYTES_PER_ROW]
            sub     esi,    ebx ; row down

            ; checking if the first pixel
            mov     eax,    DWORD[ebp-12]
            mov     ebx,    [BYTES_PER_ROW]
            add   eax,  ebx   ; eax = address of the pixel
            sub   eax,  DWORD[ebp-4]    ; eax -= array start
            xor   edx,  edx             ; edx = 0 (for div to work correctly)
            mov   ecx,  ebx
            div   ecx

            mov     eax,    edx
            xor     edx,    edx
            mov     ecx,    3
            div     ecx
            mov     ebx,    0
            cmp     ebx,    eax
            je      .skip_2

            mov     ebx,    DWORD[ebp-24]
            mov     DWORD[ebp-52],  ebx
            add     DWORD[ebp-52],  6
            jmp     .border_3

        .skip_2: ; skip to the border before height
            mov     esi,    DWORD[ebp-12]
            add     esi,    DWORD[ebp-32]
            add     esi,    DWORD[ebp-20]

            jmp     .border_3_end

        ; stage 9
        .border_3:
            mov     eax,    esi
            mov     ebx,    [BYTES_PER_ROW]
            add     eax,    ebx

            cmp     eax,    DWORD[ebp-8]
            jge     .border_3_end

            mov     DWORD[ebp-44],  9
            jmp     .get_pixel_color

        .border_3_continue:
            cmp     DWORD[ebp-16],  0
            je     .go_to_next_marker

            mov     ebx,    DWORD[ebp-52]
            cmp     DWORD[ebp-48], ebx
            je      .border_3_end
            add     DWORD[ebp-48],  3
            mov     ebx,    [BYTES_PER_ROW]
            add     esi,    ebx
            jmp     .border_3

        .border_3_end:
            mov     DWORD[ebp-48],  3
            mov     ebx,    DWORD[ebp-28]
            mov     DWORD[ebp-52],  ebx
            mov     esi,    DWORD[ebp-12]
            mov     ebx,    [BYTES_PER_ROW]
            sub     esi,    ebx     ; row  down, belowe the point where arms cross

            cmp     esi,    DWORD[ebp-4]
            jl      .add_to_buffer

            jmp     .border_4

        .border_4:
            mov     eax,    esi
            add     eax,    3

            mov     DWORD[ebp-44],  10
            jmp     .get_pixel_color

        .border_4_continue:
            cmp     DWORD[ebp-16],  0
            je     .go_to_next_marker

            mov     ebx,    DWORD[ebp-52]
            cmp     DWORD[ebp-48], ebx
            je      .border_4_end
            add     DWORD[ebp-48],  3
            add     esi,    3
            jmp     .border_4_continue

        .border_4_end:
            mov     esi,    DWORD[ebp-40]
            jmp     .add_to_buffer

    .add_to_buffer:
        mov     eax,    DWORD[ebp-36]
        mov     ecx,    DWORD[ebp-12]

        mov     DWORD[eax],     ecx
        add     DWORD[ebp-36],  4

        inc     DWORD[ebp-56]

        jmp     .go_to_next_marker

    .go_to_next_marker:
        mov     DWORD[ebp-44],  0
        mov     esi,    DWORD[ebp-40]
        jmp     .next_marker

.find_marker_end:
    mov     eax,    esi
    sub     eax,    DWORD[ebp-4]
    jmp     .end


.get_pixel_color:
    mov     ecx,    0   ; reset ecx
    mov     cl,     BYTE[eax+2] ; road R
    shl     ecx,    8   ; make space for G
    mov     cl,     BYTE[eax+1] ; load G
    shl     ecx,    8
    mov     cl,     BYTE[eax]   ; load B
    mov     DWORD[ebp-16],    ecx

    cmp     DWORD[ebp-44],  0
    je      .next_black_continue
    cmp     DWORD[ebp-44],  1
    je      .height_continue
    cmp     DWORD[ebp-44],  2
    je      .thick_continue
    cmp     DWORD[ebp-44],  3
    je      .width_continue
    cmp     DWORD[ebp-44],  4
    je      .thickness_width_continue
    cmp     DWORD[ebp-44],  5
    je      .loop_continue
    cmp     DWORD[ebp-44],  6
    je      .loop_2_continue
    cmp     DWORD[ebp-44],  7
    je      .border_1_continue
    cmp     DWORD[ebp-44],  8
    je      .border_2_continue
    cmp     DWORD[ebp-44],  9
    je      .border_3_continue
    cmp     DWORD[ebp-44],  10
    je      .border_4_continue


.wrong_file_format:
  mov   eax,  -1
  jmp   .return

.end:
  mov   esi,  result_buffer
  jmp   .add_to_array

.add_to_array:
    mov   eax, [esi]            ; address of the current pixel
    add   esi, 4                ; next address in the result buffer

    cmp   eax, 0                ; if address = 0 -> end of buffer
    je    .return
    ; Calculate the coordinates
    mov     ebx,    [BYTES_PER_ROW]
    add   eax,  ebx
    sub   eax,  DWORD[ebp-4]    ; eax -= array start
    xor   edx,  edx
    mov   ecx,  ebx
    div   ecx                   ; eax /= ROW_SIZE, edx = eax % ROW_SIZE
    mov   ecx,  [HEIGHT_VALUE]
    sub   ecx,  eax             ; Calculate Y coordinate
    mov   edi,  [ebp+20]        ; Load address of y_pos
    mov   [edi], ecx            ; Update y_pos

    mov   eax,  edx
    xor   edx,  edx
    mov   ecx,  3
    div   ecx                   ; eax /= 3
    mov   edi,  [ebp+16]
    mov   [edi], eax            ; x in x_pos

    add esp, 12

    add   dword [ebp+16], 4     ; Move to the next x_pos entry
    add   dword [ebp+20], 4     ; Move to the next y_pos entry

    ; Return to the beginning of add_to_array to process the next pixel
    jmp   .add_to_array


.return:
    mov     eax,    DWORD[ebp-56]
    mov   esp,  ebp
    pop   ebp
    pop   esi
    ret