// Misaligned load/store sweep: the bytes a misaligned access reads or writes.
//
// A load or store at every offset of a window of cache lines and pages
// (so every line-crossing and page-crossing case is hit, with capacity
// misses in between), checked byte by byte. The window is bigger than a
// held line-crossing store needs to meet an earlier store in flight, which
// is how a store that loses the bytes past its first line shows up.
//
// tohost: 1 spec behaviour; 0xE000 + k the kind k that failed (1 ld, 2 lw,
// 3 lh, 4 sd, 5 sw, 6 sh, 7 ld/sd copy). The failing offset is left in
// `res`.
#include "common/probe.h"

#define SIZE 6144

    .section .text
    .globl main
main:
    li      s0, SCRATCH
    li      s1, SIZE

    // buf[i] = (i * 7 + 3) & 0xff
    li      t0, 0
fill:
    slli    t1, t0, 3
    sub     t1, t1, t0
    addi    t1, t1, 3
    add     t2, s0, t0
    sb      t1, 0(t2)
    addi    t0, t0, 1
    blt     t0, s1, fill

    // 1: ld
    li      s9, 1
    li      s2, 0
1:
    add     s3, s0, s2
    ld      t1, 0(s3)
    li      t3, 0
    li      t4, 7
2:
    add     t5, s2, t4
    slli    t6, t5, 3
    sub     t6, t6, t5
    addi    t6, t6, 3
    andi    t6, t6, 0xff
    slli    t3, t3, 8
    or      t3, t3, t6
    addi    t4, t4, -1
    bgez    t4, 2b
    bne     t1, t3, bad
    addi    s2, s2, 1
    li      t0, SIZE - 8
    blt     s2, t0, 1b

    // 2: lw (sign extended)
    li      s9, 2
    li      s2, 0
1:
    add     s3, s0, s2
    lw      t1, 0(s3)
    li      t3, 0
    li      t4, 3
2:
    add     t5, s2, t4
    slli    t6, t5, 3
    sub     t6, t6, t5
    addi    t6, t6, 3
    andi    t6, t6, 0xff
    slli    t3, t3, 8
    or      t3, t3, t6
    addi    t4, t4, -1
    bgez    t4, 2b
    sext.w  t3, t3
    bne     t1, t3, bad
    addi    s2, s2, 1
    li      t0, SIZE - 8
    blt     s2, t0, 1b

    // 3: lh (sign extended)
    li      s9, 3
    li      s2, 0
1:
    add     s3, s0, s2
    lh      t1, 0(s3)
    addi    t5, s2, 1
    slli    t6, t5, 3
    sub     t6, t6, t5
    addi    t6, t6, 3
    andi    t3, t6, 0xff
    slli    t3, t3, 8
    slli    t6, s2, 3
    sub     t6, t6, s2
    addi    t6, t6, 3
    andi    t6, t6, 0xff
    or      t3, t3, t6
    slli    t3, t3, 48
    srai    t3, t3, 48
    bne     t1, t3, bad
    addi    s2, s2, 1
    li      t0, SIZE - 8
    blt     s2, t0, 1b

    // 4: sd, read back by bytes, then restore the pattern
    li      s9, 4
    li      s2, 0
    li      s4, 0x1122334455667788
1:
    add     s3, s0, s2
    sd      s4, 0(s3)
    li      t4, 0
2:
    add     t5, s3, t4
    lbu     t1, 0(t5)
    slli    t6, t4, 3
    srl     t3, s4, t6
    andi    t3, t3, 0xff
    bne     t1, t3, bad
    addi    t4, t4, 1
    li      t0, 8
    blt     t4, t0, 2b
    li      t4, 0
3:
    add     t5, s2, t4
    slli    t6, t5, 3
    sub     t6, t6, t5
    addi    t6, t6, 3
    add     t1, s3, t4
    sb      t6, 0(t1)
    addi    t4, t4, 1
    li      t0, 8
    blt     t4, t0, 3b
    addi    s2, s2, 1
    li      t0, SIZE - 8
    blt     s2, t0, 1b

    // 5: sw
    li      s9, 5
    li      s2, 0
    li      s4, 0x11223344
1:
    add     s3, s0, s2
    sw      s4, 0(s3)
    li      t4, 0
2:
    add     t5, s3, t4
    lbu     t1, 0(t5)
    slli    t6, t4, 3
    srl     t3, s4, t6
    andi    t3, t3, 0xff
    bne     t1, t3, bad
    addi    t4, t4, 1
    li      t0, 4
    blt     t4, t0, 2b
    li      t4, 0
3:
    add     t5, s2, t4
    slli    t6, t5, 3
    sub     t6, t6, t5
    addi    t6, t6, 3
    add     t1, s3, t4
    sb      t6, 0(t1)
    addi    t4, t4, 1
    li      t0, 4
    blt     t4, t0, 3b
    addi    s2, s2, 1
    li      t0, SIZE - 8
    blt     s2, t0, 1b

    // 6: sh
    li      s9, 6
    li      s2, 0
    li      s4, 0x1234
1:
    add     s3, s0, s2
    sh      s4, 0(s3)
    lbu     t1, 0(s3)
    andi    t3, s4, 0xff
    bne     t1, t3, bad
    lbu     t1, 1(s3)
    srli    t3, s4, 8
    bne     t1, t3, bad
    li      t4, 0
3:
    add     t5, s2, t4
    slli    t6, t5, 3
    sub     t6, t6, t5
    addi    t6, t6, 3
    add     t1, s3, t4
    sb      t6, 0(t1)
    addi    t4, t4, 1
    li      t0, 2
    blt     t4, t0, 3b
    addi    s2, s2, 1
    li      t0, SIZE - 8
    blt     s2, t0, 1b

    // 7: a memcpy-like ld/sd copy, source offset a, destination offset b,
    // over a window that crosses a page; verified by bytes
    li      s9, 7
    li      s6, SCRATCH + 0x10000
    li      s7, 0
outer_a:
    li      s8, 0
outer_b:
    li      t0, 4096 - 64
    add     s2, s0, t0
    add     s2, s2, s7
    add     s3, s6, s8
    li      t4, 0
1:
    add     t5, s2, t4
    ld      t1, 0(t5)
    add     t6, s3, t4
    sd      t1, 0(t6)
    addi    t4, t4, 8
    li      t0, 1024
    blt     t4, t0, 1b
    li      t4, 0
2:
    add     t5, s2, t4
    lbu     t1, 0(t5)
    add     t6, s3, t4
    lbu     t3, 0(t6)
    bne     t1, t3, bad7
    addi    t4, t4, 1
    li      t0, 1024
    blt     t4, t0, 2b
    addi    s8, s8, 1
    li      t0, 8
    blt     s8, t0, outer_b
    addi    s7, s7, 1
    li      t0, 8
    blt     s7, t0, outer_a

    REPORT  1

bad7:
    slli    s2, s7, 8
    or      s2, s2, s8
    slli    s2, s2, 16
    or      s2, s2, t4
bad:
    la      t0, res
    sd      s2, 0(t0)
    sd      t4, 8(t0)
    sd      t1, 16(t0)
    sd      t3, 24(t0)
    sd      s3, 32(t0)
    li      t0, 0xE000
    add     t0, t0, s9
    REPORT_REG t0

    .section .data
    .align 3
res:    .space 40

    // spike needs it to find the HTIF pair; the core's harness ignores it
    .section .tohost, "aw", @progbits
    .globl fromhost
fromhost:
    .dword 0
