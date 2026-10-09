#
# Makefile for Open Watcom C (wmake) to compile a 16 bit MS-DOS version of
# Vim for the IBM PC/XT: 8088, 640K, real mode, large memory model.
#
# Cross-builds on any host Open Watcom 2 runs on.  From the src directory:
#	wmake -f Make_wat.mak
#	wmake -f Make_wat.mak DEBUG=1	(stack checking, debug info)
#	wmake -f Make_wat.mak clean
#
# Matches Makefile.bcc: large model (-ml), 8086/8088 only (-0), no floating
# point (-fpc, nothing uses it), MIN_FEAT (default for MSDOS in feature.h).
#

CC = wcc
LINK = wlink

OBJDIR = objwat

# -0	8086/8088 instructions only
# -ml	large memory model
# -bt=dos  target DOS
# -j	signed char, like Borland
# -zq	quiet
# -fpc	floating point calls (none are used)
# -zt	put data items larger than this many bytes in far segments
CFLAGS = -zq -0 -ml -bt=dos -j -fpc -zt=256 -iproto -dMSDOS -dPC

!ifdef DEBUG
# -d2	full debug info, -od no optimisation; stack checking stays on
CFLAGS += -d2 -od
LFLAGS = debug all
STACK = 16384
!else
# -os	optimise for size, -s no stack checking
CFLAGS += -os -s
LFLAGS =
STACK = 8192
!endif

OBJ = &
	$(OBJDIR)/buffer.obj &
	$(OBJDIR)/charset.obj &
	$(OBJDIR)/digraph.obj &
	$(OBJDIR)/edit.obj &
	$(OBJDIR)/eval.obj &
	$(OBJDIR)/ex_cmds.obj &
	$(OBJDIR)/ex_docmd.obj &
	$(OBJDIR)/ex_getln.obj &
	$(OBJDIR)/fileio.obj &
	$(OBJDIR)/getchar.obj &
	$(OBJDIR)/main.obj &
	$(OBJDIR)/mark.obj &
	$(OBJDIR)/memfile.obj &
	$(OBJDIR)/memline.obj &
	$(OBJDIR)/menu.obj &
	$(OBJDIR)/message.obj &
	$(OBJDIR)/misc1.obj &
	$(OBJDIR)/misc2.obj &
	$(OBJDIR)/multbyte.obj &
	$(OBJDIR)/normal.obj &
	$(OBJDIR)/ops.obj &
	$(OBJDIR)/option.obj &
	$(OBJDIR)/os_msdos.obj &
	$(OBJDIR)/quickfix.obj &
	$(OBJDIR)/regexp.obj &
	$(OBJDIR)/screen.obj &
	$(OBJDIR)/search.obj &
	$(OBJDIR)/syntax.obj &
	$(OBJDIR)/tag.obj &
	$(OBJDIR)/term.obj &
	$(OBJDIR)/ui.obj &
	$(OBJDIR)/undo.obj &
	$(OBJDIR)/window.obj &
	$(OBJDIR)/version.obj

INCL = vim.h globals.h option.h keymap.h macros.h ascii.h term.h &
	os_msdos.h os_dos.h structs.h feature.h

all: vim.exe .SYMBOLIC

vim.exe: $(OBJDIR) $(OBJ)
	%create $(OBJDIR)/vim.lnk
	%append $(OBJDIR)/vim.lnk system dos
	%append $(OBJDIR)/vim.lnk option quiet
	%append $(OBJDIR)/vim.lnk option stack=$(STACK)
	%append $(OBJDIR)/vim.lnk option map=$(OBJDIR)/vim.map
	%append $(OBJDIR)/vim.lnk name vim.exe
	for %f in ($(OBJ)) do %append $(OBJDIR)/vim.lnk file %f
	$(LINK) $(LFLAGS) @$(OBJDIR)/vim.lnk

$(OBJDIR):
	mkdir $(OBJDIR)

.c: .
.c{$(OBJDIR)}.obj: .AUTODEPEND
	$(CC) $(CFLAGS) -fr=$(OBJDIR)/$^&.err -fo=$@ $[@

clean: .SYMBOLIC
	rm -rf $(OBJDIR)
	rm -f vim.exe
