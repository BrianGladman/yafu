dnl Copyright (C) 2004 Jens Franke, T.Kleinjung
dnl This file is part of gnfs4linux, distributed under the terms of the
dnl GNU General Public Licence and WITHOUT ANY WARRANTY.

dnl You should have received a copy of the GNU General Public License along
dnl with this program; see the file COPYING.  If not, write to the Free
dnl Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
dnl 02111-1307, USA.

#include "underscore.h"

define(FB_src,%rdi)dnl
define(proots_src,%rsi)dnl
define(fbsz_src,%rdx)dnl
define(a0_arg,%rcx)dnl
define(a1_arg,%r8)dnl
define(b0_arg,%r9)dnl
define(a0_src,56(%rsp))dnl
define(a1_src,64(%rsp))dnl
define(b0_src,72(%rsp))dnl
define(b1_src,88(%rsp))dnl
define(ri_ptr_src,96(%rsp))dnl
define(FB,%r12)dnl
define(ri_ptr,%r13)dnl
define(FB_ub,%r14)dnl
define(proots,%rbp)dnl
define(p,%r15)dnl
define(r,%rbx)dnl
define(p32,%r15d)dnl
define(r32,%ebx)dnl
dnl Hilfsvariablen
define(aux0,%rax)dnl
define(aux1,%rdx)dnl
define(aux1d,%edx)dnl
define(aux2,%r8)dnl
define(x,%r9)dnl
define(x32,%r9d)dnl
dnl r10 and r11 not used by asm_modinv32b
define(aux3,%r10)dnl
define(inv,%r11)dnl

dnl Use this comment for lines contributing to the calculation of x
define(Xcal,)dnl
define(X1cal,)dnl
define(Ycal,)dnl
define(Y1cal,)dnl
define(Ical,)dnl
dnl %eax and %edx are used in the division.

dnl In general we have to calculate
dnl  ( +- a_1 + rb_1 ) / (+- a_0 - rb_0 ) modulo p.
dnl The signs of a_0 and a_1 depend on the lattice; for each choice we have
dnl a function asm_lasieve_mm_setup'i' , i=0,1,2,3.
dnl
dnl The calculation is done as follows:
dnl Let p be fixed and R(a)=a/2^32 mod p.
dnl We first compute num=R(+- a_1 + rb_1) and den=R(R(+- a_0 - rb_0)).
dnl For den!=0 the result is R(num*den^-1).
dnl If two successive prime ideals of the factor base lie over the same prime p
dnl we try to save one inversion using a trick of Montgomery (rarely one of the
dnl denominators is zero; in this case we do the two calculations seperately).
dnl R(a) is calculated as in Montgomery multiplication.


dnl case a0>=0, a1>=0:	i=0
dnl case a0>=0, a1<0:	i=1
dnl case a0<0, a1>=0:	i=2
dnl case a0<0, a1<0:	i=3
dnl asm_lasieve_mm_setup`'i`'_64(FB,proots,fbsz,absa0,b0_ul,absa1,b1_ul,ri_ptr)

forloop(i,0,3,`
function_head(asm_lasieve_mm_setup`'i`'_64)
	subq $80,%rsp
	movq %rbx,8(%rsp)
	movq %r12,16(%rsp)
	movq %r13,24(%rsp)
	movq %r14,32(%rsp)
	movq %r15,40(%rsp)
	movq %rbp,48(%rsp)
	movq a0_arg,a0_src
	movq a1_arg,a1_src
	movq b0_arg,b0_src
	movq FB_src,FB
	movq proots_src,proots
	leaq (FB,fbsz_src,4),FB_ub
	movq ri_ptr_src,ri_ptr

dnl Begin of long long long loop
loop`'i`'_64:
dnl FB and proots are 4 byte arrays
	movl (FB),p32
	movl (proots),r32
	cmpq p,r
	movq p,aux0
	jz sc`'i`'_64
	shrq $1,aux0
	andq $0x7f,aux0
dnl smjs	movzbq mpqs_256_inv_table(aux0),inv
	leaq mpqs_256_inv_table(%rip),inv
	movzbq (inv,aux0),inv

	movq inv,aux0
	mulq p
	mulq inv
	addq inv,inv
	subq aux0,inv

	movq inv,aux0
	mulq p
	mulq inv
	addq inv,inv
	subq aux0,inv

	movq inv,aux0
	mulq p
	mulq inv
	addq inv,inv
	subq aux0,inv
dnl inv*p=1 mod 2^64

dnl case 0: x=(p-r)*b0+a0, y=(p-r)*b1+a1, x <- -y/x
dnl case 1: x=(p-r)*b0+a0, y=r*b1+a1, x <- y/x
dnl case 2: x=r*b0+a0, y=(p-r)*b1+a1, x <- y/x
dnl case 3: x=r*b0+a0, y=r*b1+a1, x <- -y/x
dnl i=0,1: p-r  i=2,3: r
ifelse(eval((i)*(i-1)),0,`
	movq p,aux0
	subq r,aux0',`
	movq r,aux0')
	mulq b0_src
	movq a0_src,aux2
	movq $0,aux3
	addq aux0,aux2
	adcq aux1,aux3
	movq inv,aux0
	mulq aux2
	movq $0,aux2
	mulq p
	subq aux1,aux3
	cmovcq p,aux2
	addq aux2,aux3
dnl x*2^-64 in aux3
	jz inf`'i`'_64

	movq inv,aux0
	mulq aux3
	movq $0,x
	mulq p
	cmovcq p,x
	subq aux1,x
dnl x*2^-128 in x

dnl i=0,2: p-r  i=1,3: r
ifelse(eval((i)*(i-2)),0,`
	movq p,aux0
	subq r,aux0',`
	movq r,aux0')
	mulq b1_src
	movq a1_src,aux2
	movq $0,aux3
	addq aux0,aux2
	adcq aux1,aux3
	movq inv,aux0
	mulq aux2
	movq $0,aux2
	mulq p
	subq aux1,aux3
	cmovcq p,aux2
	addq aux2,aux3
dnl y*2^-64 in aux3

	movl x32,%edi
	movl p32,%esi
dnl smjs	call asm_modinv32b
	call asm_modinv32b

	mulq aux3
	movq aux0,aux2
	movq aux1,aux3
	mulq inv
	movq $0,aux2
	mulq p
	subq aux1,aux3
	cmovcq p,aux2
	addq aux2,aux3
dnl y/x in aux3
dnl i=0,3: -  i=1,2: +
ifelse(eval((i-1)*(i-2)),0,`
	movq aux3,aux0',`
	movq p,aux0
	subq aux3,aux0
	testq aux3,aux3
	cmovzq aux3,aux0')
dnl +-y/x in aux0
cri`'i`'_64:
	movq ri_ptr,%rdi
	movl p32,%esi
	movl %eax,%edx

dnl smjs	call get_recurrence_info
	call get_recurrence_info

	leaq 4(FB),FB
	cmpq FB,FB_ub
	leaq 4(proots),proots
	leaq 8(ri_ptr),ri_ptr
	ja loop`'i`'_64
	movq ri_ptr,%rax
	movq 8(%rsp),%rbx
	movq 16(%rsp),%r12
	movq 24(%rsp),%r13
	movq 32(%rsp),%r14
	movq 40(%rsp),%r15
	movq 48(%rsp),%rbp
	addq $80,%rsp
	ret

dnl special cases, need not be efficient
sc`'i`'_64:
	movq b0_src,aux0
	xorq aux1,aux1
	divq p
	testq aux1,aux1
	movq p,aux0
	jz cri`'i`'_64
	movl aux1d,%edi
	movl p32,%esi
dnl smjs        call asm_modinv32b
        call asm_modinv32b
	movq aux0,aux2

	movq b1_src,aux0
	xorq aux1,aux1
	divq p
	movq aux1,aux0
	mulq aux2
	divq p
	movq p,aux0
	subq aux1,aux0
	testq aux1,aux1
	cmovzq aux1,aux0
	jmp cri`'i`'_64

inf`'i`'_64:
	movq p,aux0
	jz cri`'i`'_64
')
