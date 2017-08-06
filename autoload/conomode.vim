" Vim plugin -- Vi-style editing for the cmdline
" General: {{{1
" File:		conomode.vim
" Created:	2008 Sep 28
" Last Change:	2017 Jun 04
" Version:	0.9.32 (undo, nesting)
"		reverted from (macro, undo, nesting)
" License:      Vim License, see :h license
" Author:	Andy Wokula <anwoku@yahoo.de>
" Vim Version:	7.3 (older Vims may crash)
" Credits:
"   inspired from a vim_use thread on vi-style editing in the bash (there
"   enabled with 'set -o vi').
"   Subject:  command line
"   Date:     25-09-2008

" Description: {{{1
"   Implements a kind of Normal mode ( "Cmdline-Normal mode" ) for the
"   Command line.  Great fun if   :h cmdline-window   gets boring ;-)

" Installation: {{{1
" - put this script into your autoload folder
" - in your vimrc, map CTRL-O (or any other key) as follows:
"	:cmap <expr> <C-O> conomode#Plug()

" Usage: {{{1
" - when in Cmdline-mode, hit <C-O> to enter "Commandline-Normal mode"
"   (the key was <F4> in older versions)
" - mode indicator: a colon ":" at the cursor, hiding the char under it
"   (side effect of incomplete mapping)
" - quit to Cmdline-mode with "i", ":", or any unmapped key (which then
"   executes or inserts itself), or wait 60 seconds.

" Features So Far: {{{1
" - Motions: h l w b e W B E 0 ^ $ f{char} F{char} t{char} T{char} ; , %
"   also in Operator pending mode
" - Operators: d y c
"   these write to the unnamed register; c prompts for input()
" - Simple Changes: r{char} ~
" - Putting: P p
"   puts the unnamed register
" - Mode Switching:
"   I i a A - back to Cmdline (with positioned cursor), <Esc> - back to
"   Normal mode, <CR> - execute Cmdline, : - back to Cmdline (remove all
"   text)
" - Insert: o
"   input() version of i (versus i: accepts a count)
" - Repeating: .
"   repeatable commands: d r c ~ o
"   also: I i a A
" - Undo: u U
"   redo with "U" (to keep c_CTRL-R working); undo information survives mode
"   switching; undo is unlimited
" - Count: can be given for most commands
" - Shortcuts: yy Y dd D x X cc C s S
"   yy -> y_, Y -> y$, dd -> d_, D -> d$, x -> dl, X -> dh, cc -> c_,
"   C -> c$, s -> cl, S -> 0d$i
" - Misc: <C-L> - redraw the Cmdline, gX - cut undo (forget older entries),
"   g= - (operator) evaluate and replace with result

" Incompatibilities: (some ...) {{{1
" - redo with "U" (instead of "<C-R>")

" Small Differences:
" - "e" jumps after the word, "$" jumps to EOL (after last char in the
"   line), "e" and "$" are exclusive
" - at EOL, "x", "dl", "dw" etc. do not go left to delete at least one
"   character
" - typing "dx" does "x", ignoring "d"; same for similar situations
" - "c", "r", "~": no undo step if old and new text are equal; "i": no undo
"   step if nothing inserted
" - "yy" yanks characterwise

" Notes: {{{1
" - strange: utf-8 characters are garbled by the mode indicator; press
"   Ctrl-L to redraw; (!) fixed with patch 7.3.539
" - how to find out which keys are mapped in the mode?
"	:call conomode#Debug()
"	:ConomodeLocal cmap <SID>:
" - mapping <SID>:<BS> (<BS> = a key code expanding to several bytes)
"   doesn't work; probably this is related to a known Vim bug:
"	:h todo|/These two abbreviations don't give the same result:
" - manipulation of cmdline and cursor position uses getcmdline(),
"   c_CTRL-\_e, c_CTRL-R_=, getcmdpos(), setcmdpos()
" - ok: "3fx;;" -- do not remember the count for ";"
" - ok: "cw{text}<CR>5." -- "5." does "5cw{text}<CR>"
" - <C-R>= and <C-\>e cannot be used at the '=' prompt, but otherwise
"   recursion is allowed
" - VALIDCMDTYPE do not call a function to check getcmdtype(), it becomes
"   annoying at the debug prompt for keys mapped with conomode#map#Cmap()

" TODO: {{{1
" - mark: m and `
" ? refactor s:count1?
" ? recursive <F4>
" - support more registers, make '"adw' work
" - last-position jump, ``
" ? (non-vi) somehow enable Smartput??
" -- (from vile) "q" in Operator-pending mode records a motion
" - <F4>i{text}<F4> (or just {text}<F4>): starting with empty cmdline can't
"   be repeated
" - search commands "/", "?", "n", "N" for the cmd-history
" - make ":" work like in ctmaps.vim
" - zap to multi-byte char
"
" (newest last)
" + count: [1-9][0-9]* enable zero after one non-zero
" + count with multiplication: 2d3w = 6dw
" + count: f{char}, F{char}; r{char}; undo; put
" + "c" is repeatable
" + BF compare old and new text case sensitive
" + BF for now, disable recursive <F4>
" + BF opend(), allow "c" on zero characters
" + doop_c: no default text, instead add old text to input history
" + BF doop_c: escape chars in input string for use in mapping (?) - yes!
" + implement "i", "I" and "A" with input(), like "c"
" + no need longer need to type <C-U> in "c{motion}<C-U>{text}<CR>"
" + BF doop_c, opend: c{motion} should leave the cursor after the change
" + command "a": move right first
" + continuous undo (don't break undo when switching to Cmdline-mode)
" + multi-byte support (!): some commands moved bytewise, not characterwise
"   (Mbyte); noch was übersehen?
" + BF <F4>-recursion prevention did <C-R>= within <C-\>e (not allowed)
" + remove the [count] limits (e.g. don't expand "3h" to "<Left><Left><Left>")
"   what about  "3h" -> "<Left>2h", "50@" -> "@49@"; simple motions only
"   ! do "<Left><Left><Left><SID>dorep", while count > 0
" + NF "%" motion, motions can become inclusive (added s:incloff)
" + NF motion "|"
" + BF "f" now inclusive
" + NF added "t" and "T" (always move cursor, as in newer Vims)
" + NF each cmdtype (':', '/?') gets separate undo data (hmm, Ctrl-C wipes
"   undo data)
" + whole-line text object for "cc", "dd", etc. (repeat used c$, d$)
" + s:getpos_* functions now return 0-based positions (1-based sux)
" + BF: cmdl "infiles", inserting "filou" before "f" made try_continue_undo
"   detect "oufil" as inserted part; now use cursor position to decide
" + NF: "gX" - cut older undo states (non-vi)
" + NF: permit nesting (!)
" + (non-vi) "c", "i": if the last inserted char is a parenthesis (and it is
"   the only one), then "." will insert the corresponding paren
"   ! insert only, very simple, just see how it works; s:ModifyLastEdit()
" + removed g:conomode_emacs_keys
" + BF: made I, i, a, A actual commands
" * refact s:doop and s:getpos funcs, now use dicts
" + NF: conomode#map#Cmap()
" + CH: "yy", "dd", "cc", "_" motion now linewise

" }}}

" Init: {{{1
let conomode#loaded = 1

let s:cpo_sav = &cpo
set cpo&vim

" Config: {{{1

if !exists("g:conomode_undo_maker")
    let g:conomode_undo_maker = "conomode#undo#default#New"
endif

" Some Local Variables: {{{1
if !exists("s:doop")
    let s:doop = {}
endif
if !exists("s:getpos")
    let s:getpos = {}
endif
if !exists("s:undo")
    let s:undo = {}
endif
if !exists("s:quitnormal")
    let s:quitnormal = 1
endif
if !exists("s:nested")
    let s:nested = 0
endif
if !exists("s:undostore")
    let s:undostore = {}
endif
if !exists("s:insbegin")
    let s:insbegin = "i"
endif
if !exists("s:register")
    let s:register = ''
endif

" word forward patterns:
let s:wfpat = {
    \  "w": ['\k*\s*\zs', '\s*\zs', '\%(\k\@!\S\)*\s*\zs']
    \, "W": ['\S*\s*\zs', '\s*\zs', '\S*\s*\zs']
    \, "e": ['\k\+\zs', '\s*\%(\k\+\|\%(\k\@!\S\)*\)\zs', '\%(\k\@!\S\)*\zs']
    \, "E": ['\S\+\zs', '\s*\S*\zs', '\S*\zs']
    \}

let s:wbpat = {
    \  "b": ['\k*$', '\%(\k\+\|\%(\k\@!\S\)*\)\s*$', '\%(\k\@!\S\)*$']
    \, "B": ['\S*$', '\S*\s*$', '\S*$']
    \}

let s:stacked_vars = split('s:lastcount s:lastedit s:lastitext s:lastzap s:operator')

let s:file = expand('<sfile>')
"}}}1

" Functions:
" Getpos: {{{1
func! s:forward_word(wm, count1)
    " wm - word motion: w, W or e
    let pat = s:wfpat[a:wm]
    let cnt = a:count1
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()[gcp :]
    while 1
	let cpchar = matchstr(cmdl, '^.')
	if cpchar =~ '\k'
	    let matpos = match(cmdl, pat[0])
	elseif cpchar =~ '\s'
	    let matpos = match(cmdl, pat[1])
	else
	    let matpos = match(cmdl, pat[2])
	endif
	let cnt -= 1
	if cnt <= 0 || matpos <= 0
	    break
	endif
	let gcp += matpos
	let cmdl = cmdl[matpos :]
    endwhile
    let newcp = gcp + matpos
    return newcp
endfunc

func! s:getpos.w()
    return s:forward_word("w", s:count1)
endfunc

func! s:getpos.W()
    return s:forward_word("W", s:count1)
endfunc

func! s:getpos.e()
    return s:forward_word("e", s:count1)
endfunc

func! s:getpos.E()
    return s:forward_word("E", s:count1)
endfunc

func! s:backward_word(wm, count1)
    let pat = s:wbpat[a:wm]
    let cnt = a:count1
    let gcp = getcmdpos()-1
    let cmdl = strpart(getcmdline(), 0, gcp)
    while gcp >= 1
	let cpchar = matchstr(cmdl, '.$')
	if cpchar =~ '\k'
	    let gcp = match(cmdl, pat[0])
	elseif cpchar =~ '\s'
	    let gcp = match(cmdl, pat[1])
	else
	    let gcp = match(cmdl, pat[2])
	endif
	let cnt -= 1
	if cnt <= 0 || gcp <= 0
	    break
	endif
	let cmdl = strpart(cmdl, 0, gcp)
    endwhile
    return gcp
endfunc

func! s:getpos.b()
    return s:backward_word("b", s:count1)
endfunc

func! s:getpos.B()
    return s:backward_word("B", s:count1)
endfunc

func! s:getpos.h()
    " Omap mode only
    let gcp = getcmdpos()-1
    if s:count1 > gcp
	return 0
    elseif s:count1 == 1
	if gcp >= 8
	    return gcp-8+match(strpart(getcmdline(), gcp-8, 8), '.$')
	else
	    return match(strpart(getcmdline(), 0, gcp), '.$')
	endif
    endif
    let pos = match(strpart(getcmdline(), 0, gcp), '.\{'.s:count1.'}$')
    return pos >= 0 ? pos : 0
endfunc

func! s:getpos.l()
    let gcp = getcmdpos()-1
    if s:count1 == 1
	return matchend(getcmdline(), '.\|$', gcp)
    endif
    let cmdlsuf = strpart(getcmdline(), gcp)
    let lensuf = strlen(cmdlsuf)
    if s:count1 >= lensuf
	return gcp+lensuf
    else
	return gcp+matchend(cmdlsuf, '.\{'.s:count1.'}\|$')
    endif
endfunc

func! s:getpos.dollar()
    return strlen(getcmdline())
endfunc

func! s:getpos.zero()
    return 0
endfunc

func! s:getpos.caret()
    return match(getcmdline(), '\S')
endfunc

" jump to matching paren
func! s:getpos.percent()
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()
    if cmdl[gcp] !~ '[()[\]{}]'
	let ppos = match(cmdl, '[()[\]{}]', gcp)
	if ppos == -1
	    return gcp
	endif
    else
	let ppos = gcp
    endif
    " balance counter, paren position, opening/closing paren character,
    " first opening/closing (paren) position
    let pairs = '()[]{}'
    let bc = 1
    if cmdl[ppos] =~ '[([{]'
	let opc = cmdl[ppos]
	let cpc = pairs[stridx(pairs, opc)+1]
	let fop = stridx(cmdl, opc, ppos+1)
	let fcp = stridx(cmdl, cpc, ppos+1)
	while 1
	    if fcp == -1
		return gcp
	    elseif bc==1 && (fop == -1 || fcp < fop)
		let s:incloff = 1
		return fcp
	    endif
	    if fop >= 0 && fop < fcp
		let bc += 1
		let fop = stridx(cmdl, opc, fop+1)
	    else
		let bc -= 1
		let fcp = stridx(cmdl, cpc, fcp+1)
	    endif
	endwhile
    else
	let cpc = cmdl[ppos]
	let opc = pairs[stridx(pairs, cpc)-1]
	let fcp = strridx(cmdl, cpc, ppos-1)
	let fop = strridx(cmdl, opc, ppos-1)
	while 1
	    if fop == -1
		return gcp
	    elseif bc==1 && (fcp == -1 || fop > fcp)
		let s:incloff = 1
		return fop
	    endif
	    if fcp > fop
		let bc += 1
		let fcp = strridx(cmdl, cpc, fcp-1)
	    else
		let bc -= 1
		let fop = strridx(cmdl, opc, fop-1)
	    endif
	endwhile
    endif
    return gcp
endfunc

func! s:getpos.bar()
    let cmdl = getcmdline()
    let pos = byteidx(cmdl, s:count1-1)
    if pos == -1
	return strlen(cmdl)
    else
	return pos
    endif
endfunc

func! s:getpos.backtick()
    let gcp = getcmdpos()-1
    if exists("s:mark") && s:mark >= 0
	let new_mark = s:mark
	let s:mark = gcp
	return new_mark
    else
	return gcp
    endif
endfunc

" Getzappos: {{{1
func! s:getzappos(zapcmd, ...)
    let cnt = s:count1
    if a:0 == 0
	call inputsave()
	let aimchar = nr2char(getchar())
	call inputrestore()
	let s:lastzap = [a:zapcmd, aimchar]
    else
	let aimchar = a:1
    endif
    let gcp = getcmdpos()-1
    let newcp = gcp
    let cmdl = getcmdline()
    if a:zapcmd ==# "f" || a:zapcmd ==# "t"
	if a:zapcmd ==# "t"
	    let newcp += 1
	endif
	while cnt >= 1 && newcp >= 0
	    let newcp = stridx(cmdl, aimchar, newcp+1)
	    let cnt -= 1
	endwhile
	if newcp < 0
	    let newcp = gcp
	else
	    if a:zapcmd ==# "t"
		" FIXME multibyte?
		let newcp -= 1
	    endif
	    let s:incloff = 1
	endif
    else " F
	if a:zapcmd ==# "T"
	    let newcp -= 1
	endif
	while cnt >= 1 && newcp >= 0
	    let newcp = strridx(cmdl, aimchar, newcp-1)
	    let cnt -= 1
	endwhile
	if newcp < 0
	    let newcp = gcp
	elseif a:zapcmd ==# "T"
	    " multibyte?
	    let newcp += 1
	endif
    endif
    let s:beep = newcp == gcp
    return newcp
endfunc

func! s:getpos.f()
    return s:getzappos("f")
endfunc

func! s:getpos.F()
    return s:getzappos("F")
endfunc

func! s:getpos.t()
    return s:getzappos("t")
endfunc

func! s:getpos.T()
    return s:getzappos("T")
endfunc

func! s:getpos.scolon()
    if exists("s:lastzap")
	return s:getzappos(s:lastzap[0], s:lastzap[1])
    else
	return getcmdpos()-1
    endif
endfunc

func! s:getpos.comma()
    if exists("s:lastzap")
	return s:getzappos(tr(s:lastzap[0],'fFtT','FfTt'), s:lastzap[1])
    else
	return getcmdpos()-1
    endif
endfunc

" Move: {{{1
func! <sid>move(motion)
    let s:count1 = s:getcount1()
    call setcmdpos(1 + s:getpos[a:motion]())
    return ""
endfunc

func! <sid>move_zap(zapcmd)
    let s:count1 = s:getcount1()
    call setcmdpos(1 + s:getzappos(a:zapcmd))
    return ""
endfunc

" Put: {{{1
func! <sid>edit_put(mode, reg, gcpoff, endoff)
    let reg = a:reg != '' ? a:reg : (s:register != '' ? s:register : '"')
    let s:register = ''
    let coff = a:gcpoff
    if a:mode == 1
	" limit count to 500
	let cnt = min([s:getcount1(),500])
	let s:lastedit = ["edit_put", 0, reg, coff, a:endoff]
	let s:lastcount = cnt
    else
	let cnt = s:lastcount
    endif
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()
    if coff == 1 && cmdl[gcp] == ""
	let coff = 0
    endif
    let boff = coff==0 ? 0 : matchend(strpart(cmdl, gcp, 8), '.')
    let ins = repeat(getreg(reg), cnt)
    if ins != ""
	" after undoing "p", move the cursor one left from the start of the
	" change
	call s:undo.add(0, "m", gcp, "")
	call s:undo.add(1, "i", gcp+boff, ins)
	call setcmdpos(gcp+1+strlen(ins)+boff+a:endoff)
    endif
    return strpart(cmdl, 0, gcp+boff). ins. strpart(cmdl, gcp+boff)
endfunc

" Edit: {{{1
func! <sid>edit_r(mode, ...)
    if a:mode == 1
	let cnt = s:getcount1()
	call inputsave()
	let replchar = nr2char(getchar())
	call inputrestore()
	let s:lastedit = ["edit_r", 0, replchar]
	let s:lastcount = cnt
    else
	let replchar = a:1
	let cnt = s:lastcount
    endif
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()
    let ripos = matchend(cmdl, '.\{'.cnt.'}', gcp)
    if ripos >= 1
	let mid = cmdl[gcp : ripos-1]
	let newmid = repeat(replchar, cnt)
	if mid !=# newmid
	    call s:undo.add(0, "d", gcp, mid)
	    call s:undo.add(1, "i", gcp, newmid)
	endif
	return strpart(cmdl, 0, gcp). newmid. strpart(cmdl, ripos)
    else
	return cmdl
    endif
endfunc

func! <sid>edit_tilde(mode, ...)
    if a:mode == 1
	let cnt = s:getcount1()
	let s:lastedit = ["edit_tilde", 0]
	let s:lastcount = cnt
    else
	let cnt = s:lastcount
    endif
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()
    let ripos = matchend(cmdl, '.\{1,'.cnt.'}', gcp)
    if ripos >= 1
	let mid = cmdl[gcp : ripos-1]
	" let newmid = substitute(mid, '\(\u\)\|\(\l\)', '\l\1\u\2', 'g')
	let newmid = s:ToggleCase(mid)
	if mid !=# newmid
	    call s:undo.add(0, "d", gcp, mid)
	    call s:undo.add(1, "i", gcp, newmid)
	endif
	call setcmdpos(gcp+1 + strlen(newmid))
	return strpart(cmdl, 0, gcp). newmid. strpart(cmdl, ripos)
    else
	return cmdl
    endif
endfunc

func! <sid>setop(op)
    let s:operator = a:op
    return ""
endfunc

func! s:doop.d(str, pos, regtype, rep)
    call s:SetReg(a:str, '-', a:regtype)
    call s:undo.add(1, "d", a:pos, a:str)
    call setcmdpos(a:pos + 1)
    return ""
endfunc

func! s:doop.y(str, pos, regtype, ...)
    call s:SetReg(a:str, '"', a:regtype)
    call setcmdpos(a:pos + 1)
    return a:str
endfunc

func! s:doop.eval(str, pos, regtype, rep)
    call s:SetReg(a:str, '"', a:regtype)
    call setcmdpos(a:pos + 1)
    " tell ancompl.vim to complete functions, not commands:
    let g:ancompl_is_expr = 1
    if !a:rep
	let chainexpr = s:Input("(chain)=", "", "expression")
	let s:lastchainexpr = chainexpr
    else
	let chainexpr = s:lastchainexpr
    endif
    try
	" eval() is called outside the script
	let evalresult = nwo#desert#Let(a:str, nwo#chain#Expr(['a:val'] + nwo#fargs#Split(chainexpr)))
	let newtext = type(evalresult) == type("") ? evalresult : string(evalresult)
	if a:str !=# newtext
	    call s:undo.add(0, "d", a:pos, a:str)
	    call s:undo.add(1, "i", a:pos, newtext)
	endif
	return newtext
    catch
	call s:Warn()
	return a:str
    finally
	unlet g:ancompl_is_expr
    endtry
endfunc

func! s:ToggleCase(str)
    return substitute(a:str, '\k', '\=toupper(submatch(0))==#submatch(0) ? tolower(submatch(0)) : toupper(submatch(0))', 'g')
endfunc

" Insert: {{{1
func! s:doop.c(str, pos, regtype, rep)
    call s:SetReg(a:str, '-', a:regtype)
    if !a:rep
	call histadd("@", a:str)
	let newtext = s:Input("Change into:")
	let s:lastitext = newtext
    else
	let newtext = s:lastitext
    endif
    if a:str !=# newtext
	call s:undo.add(0, "d", a:pos, a:str)
	call s:undo.add(1, "i", a:pos, newtext)
    endif
    call setcmdpos(a:pos+1 + strlen(newtext))
    return newtext
endfunc

func! <sid>insert_begin(cmd)
    let s:insbegin = a:cmd
    if a:cmd ==# "i"
	return ""
    endif
    let cmdl = getcmdline()
    if a:cmd ==# "I"
	" special case: returns full cmdline
	let gcp = 0
	if getcmdtype() == ":"
	    let iwhite = matchstr(cmdl, '^[ \t:]*')
	    if iwhite != ""
		call s:undo.add(1, "d", gcp, iwhite)
		let cmdl = strpart(cmdl, strlen(iwhite))
	    endif
	endif
	call setcmdpos(gcp+1)
	return cmdl
    endif
    if a:cmd ==# "a"
	let gcp = matchend(cmdl, '^.\=', getcmdpos()-1)
    elseif a:cmd ==# "A"
	let gcp = strlen(cmdl)
    else
	let gcp = getcmdpos()-1
    endif
    call setcmdpos(gcp+1)
    return ""
endfunc

func! <sid>insert(mode, cmd)
    if a:mode == 1
	let cnt = s:getcount1()
	let s:lastedit = ["insert", 0, a:cmd]
	let s:lastcount = cnt
	let newtext = s:Input(a:cmd==?"a" ? "Append:" : "Insert:")
	let s:lastitext = newtext
	call s:ModifyLastEdit(1)
    else
	let cnt = s:lastcount
	let newtext = s:lastitext
	call s:ModifyLastEdit(0)	" also toggle after `.'
    endif
    let cmdl = getcmdline()
    if a:cmd ==# "I"
	let gcp = 0
	if getcmdtype() == ":"
	    let iwhite = matchstr(cmdl, '^[ \t:]*')
	    if iwhite != ""
		call s:undo.add(newtext=="", "d", gcp, iwhite)
		let cmdl = strpart(cmdl, strlen(iwhite))
	    endif
	endif
    elseif a:cmd ==# "a"
	let gcp = matchend(cmdl, '^.\=', getcmdpos()-1)
    elseif a:cmd ==# "A"
	let gcp = strlen(cmdl)
    else
	let gcp = getcmdpos()-1
    endif
    if newtext != ""
	let resulttext = repeat(newtext, cnt)
	call s:undo.add(1, "i", gcp, resulttext)
	call setcmdpos(gcp+1 + strlen(resulttext))
	return strpart(cmdl, 0, gcp). resulttext. strpart(cmdl, gcp)
    else
	call setcmdpos(gcp+1)
	return cmdl
    endif
endfunc

" Opend: {{{1
func! <sid>opend(motion, ...)
    let motion = a:motion

    if a:0 == 0
	let s:count1 = s:getcount1()
	let s:lastedit = ["opend", motion, 0]
	let s:lastcount = s:count1
	let isrep = 0
    elseif a:1 == 1
	" zap motion, a:0 == 2
	let s:count1 = s:getcount1()
	let s:lastedit = ["opend", a:2, 0]
	let s:lastcount = s:count1
	let isrep = 0
    else " e.g. a:1 == 0
	let s:count1 = s:lastcount
	let isrep = 1
    endif

    let s:incloff = 0
    let gcp = getcmdpos()-1

    " cw,cW -> ce,cE (not on white space)
    if s:operator == "c" && motion ==? "w"
	\ && getcmdline()[gcp] =~ '\S'
	let motion = tr(motion, "wW", "eE")
    endif
    if motion == '_'
	" special case, text object for a line
	let gcp = 0
	let tarpos = s:getpos.dollar()
	let regtype = "l"
    else
	let tarpos = s:getpos[motion]()
	let regtype = "c"
    endif

    let cmdl = getcmdline()
    if gcp < tarpos
	let [pos1, pos2] = [gcp, tarpos+s:incloff]
    elseif tarpos < gcp
	let [pos1, pos2] = [tarpos, gcp+s:incloff]
    elseif s:operator == "c"
	" allow changing an empty region
	let [pos1, pos2] = [gcp, gcp+s:incloff]
    else
	return cmdl
    endif

    let cmdlpart = strpart(cmdl, pos1, pos2-pos1)
    let newpart = s:doop[s:operator](cmdlpart, pos1, regtype, isrep)

    return strpart(cmdl,0,pos1). newpart. cmdl[pos2 :]
endfunc

" Repeat: {{{1
func! <sid>edit_dot()
    let cnt = s:getcount()
    if exists("s:lastedit")
	if cnt > 0
	    let s:lastcount = cnt
	endif
	return call("s:".s:lastedit[0], s:lastedit[1:])
    else
	return getcmdline()
    endif
endfunc

" Count: {{{1
func! s:getcount()
    let iszero = s:counta == "" && s:countb == ""
    let count1 = s:getcount1()
    return iszero ? 0 : count1
endfunc

func! s:getcount1()
    if s:counta != ""
	let cnta = s:counta + 0
	let s:counta = ""
	cmap <SID>:0 <SID>zero
    else
	let cnta = 1
    endif
    if s:countb != ""
	let cntb = s:countb + 0
	let s:countb = ""
	cnoremap <script> <SID>;0 <SID>ocon0<CR><SID>:
    else
	let cntb = 1
    endif
    return cnta * cntb
endfunc

func! <sid>counta(digit)
    if s:counta == ""
	cnoremap <script> <SID>:0 <SID>cono0<CR><SID>:
    endif
    let s:counta .= a:digit
    return ""
endfunc

func! <sid>countb(digit)
    if s:countb == ""
	cnoremap <script> <SID>;0 <SID>ocnt0<CR><SID>;
    endif
    let s:countb .= a:digit
    return ""
endfunc

func! <sid>eatcount(key)
    let s:counta = ""
    let s:countb = ""
    if a:key != "0"
	cmap <SID>:0 <SID>zero
    endif
    return ""
endfunc

" duplicate a basic motion count times
func! <sid>repinit(key, reckey, stopcond, ...)
    let cnt = s:getcount1()*(a:0 >= 1 ? a:1 : 1)
    if cnt == 1
	let s:rep = { "count": 0 }
	return a:key
    endif
    let s:rep = { "key": a:key, "count": cnt, "cond": a:stopcond, "gcp1": -1 }
    return ""
endfunc

func! <sid>rep(SID)
    if s:rep.count == 0
	return ""
    endif
    let gcp1 = getcmdpos()
    if s:rep.cond == "^" && gcp1 == s:rep.gcp1
	return ""
    elseif s:rep.cond == "$" && gcp1 == s:rep.gcp1
	return ""
    endif
    let s:rep.gcp1 = gcp1
    if s:rep.count < 10
	return repeat(s:rep.key, s:rep.count)
    else
	let s:rep.count -= 10
	return repeat(s:rep.key, 10). a:SID."dorep"
    endif
endfunc

" Mark {{{1
func! <sid>set_mark()
    let s:mark = getcmdpos()-1
    return ""
endfunc

" Registers {{{1

func! <sid>get_regchar()
    let chr = getchar(1) ? s:getchar() : ""
    if chr != ""
	let s:register = chr
    endif
    return ""
endfunc

func! s:getchar()
    let chr = getchar()
    return chr != 0 ? nr2char(chr) : chr
endfunc

" Init: (more local variables, continue undo) {{{1
func! <sid>set_tm()
    if s:quitnormal
	let s:tm_sav = &tm
	set timeoutlen=60000
	let s:nested_off = getcmdtype() == "@" ? 1 : 0
    endif
    let s:quitnormal = 0
    let s:counta = ""
    let s:countb = ""

    if s:nested == 0
	call s:initcmdtype_for_undo()
	call s:try_continue_undo()
    endif

    cmap <SID>:0 <SID>zero
    cnoremap <script> <SID>;0 <SID>ocon0<CR><SID>:
    return ""
endfunc

func! <sid>rst_tm()
    if s:nested == 0
	let &tm = s:tm_sav
	let s:quitnormal = 1
	let s:lastcmdline = getcmdline()
	let s:lastcmdpos = getcmdpos()
	let s:lastcmdtype = s:cmdtype
	unlet s:cmdtype
    endif
    return ""
endfunc

" do not call for s:nested >= 1
func! s:initcmdtype_for_undo()
    let s:cmdtype = tr(getcmdtype(), '?', '/')
    if !exists("s:lastcmdtype")
	call s:undo.init()
	unlet! s:lastcmdline
	unlet! s:lastcmdpos
	return
    elseif s:cmdtype == s:lastcmdtype
	unlet s:lastcmdtype
	return
    endif
    let s:undostore[s:lastcmdtype] = {
	\ 'lastcmdline': s:lastcmdline,
	\ 'lastcmdpos': s:lastcmdpos,
	\ 'undostate': s:undo.get_state()}
    if has_key(s:undostore, s:cmdtype)
	let d = s:undostore[s:cmdtype]
	call s:undo.set_state(d.undostate)
	let s:lastcmdline = d.lastcmdline
	let s:lastcmdpos = d.lastcmdpos
    else
	call s:undo.init()
	unlet! s:lastcmdline
	unlet! s:lastcmdpos
    endif
    unlet s:lastcmdtype
endfunc

" a friend of s:undo; to be called *after* s:initcmdtype_for_undo()
" do not call for s:nested >= 1
func! s:try_continue_undo()
    let inscmd = s:insbegin
    let s:insbegin = "i"
    if inscmd !=# "i"
	let s:lastedit = ["insert", 0, inscmd]
	let s:lastcount = 1
	let s:lastitext = ""
    endif
    if !exists("s:lastcmdline")
	return
    endif
    let lastcmdl = s:lastcmdline
    let cmdl = getcmdline()
    if cmdl ==# lastcmdl
	return
    endif

    if lastcmdl == ""
	if cmdl != ""
	    call s:undo.add(1, "i", 0, cmdl)
	    " enable "." for short pieces (with arbit. limit), eg don't
	    " repeat a long cmdline revoked from the history
	    if strlen(cmdl) <= 40
		let s:lastedit = ["insert", 0, inscmd]
		let s:lastcount = 1
		let s:lastitext = cmdl
		call s:ModifyLastEdit(1)
	    endif
	endif
	return
    endif

    let lastgcp = s:lastcmdpos - 1
    let gcp = getcmdpos()-1

    let lendiff = strlen(cmdl) - strlen(lastcmdl)

    if lendiff < 0
	" possible deletion
	let lendel = -lendiff
	if strpart(lastcmdl, 0, gcp) ==# strpart(cmdl, 0, gcp)
	    \ && strpart(lastcmdl, gcp+lendel) ==# strpart(cmdl, gcp)
	    let deleted = strpart(lastcmdl, gcp, lendel)
	    call s:undo.add(1, "d", gcp, deleted)
	    let s:operator = "d"
	    let s:lastcount = strchars(deleted)
	    " BACKSPACEVSDEL
	    let motion = gcp < lastgcp ? "h" : "l"
	    let s:lastedit = ["opend", motion, 0]
	    return
	endif
    endif

    if lendiff > 0
	" possible insertion
	let lenins = lendiff
	if gcp >= lenins
	    if strpart(lastcmdl, 0, gcp-lenins) ==# strpart(cmdl, 0, gcp-lenins)
		\ && strpart(lastcmdl, gcp-lenins) ==# strpart(cmdl, gcp)
		let inserted = strpart(cmdl, gcp-lenins, lenins)
		call s:undo.add(1, "i", gcp-lenins, inserted)
		let s:lastedit = ["insert", 0, inscmd]
		let s:lastcount = 1
		let s:lastitext = inserted
		call s:ModifyLastEdit(1)
		return
	    endif
	endif
    endif

    let lenlastcmdl = strlen(lastcmdl)
    let lencmdl = strlen(cmdl)
    let lentail = lencmdl - gcp
    if lenlastcmdl < lentail
	let lentail = lenlastcmdl
	" new gcp
	let ngcp = lencmdl - lentail
    else
	let ngcp = gcp
    endif
    if strpart(lastcmdl, lenlastcmdl-lentail) !=# strpart(cmdl, ngcp)
	" find common suffix, move ngcp to its begin
	let back_pat = s:PrefixPat(s:Reverse(strpart(lastcmdl, lenlastcmdl-lentail)))
	let lensuf = strlen(matchstr(s:Reverse(strpart(cmdl, ngcp)), back_pat))
	let ngcp = lencmdl - lensuf
    else
	let lensuf = lentail
    endif
    unlet lentail
    " new-gcp: there is no change right from this position
    let lastcmdlhead = strpart(lastcmdl, 0, lenlastcmdl-lensuf)
    let cmdlhead = strpart(cmdl, 0, ngcp)

    if lenlastcmdl > lensuf
	let forw_pat = s:PrefixPat(lastcmdlhead)
	let lenpre = strlen(matchstr(cmdlhead, forw_pat))
    else
	let lenpre = 0
    endif

    let deleted = strpart(lastcmdlhead, lenpre)
    let inserted = strpart(cmdlhead, lenpre)
    " `deleted' and `inserted' may still have a common suffix
    " (XXX maybe exclude for undo?)
    let has_delete = deleted != ""
    let has_insert = inserted != ""

    if has_delete
	call s:undo.add(!has_insert, "d", lenpre, deleted)
	if !has_insert
	    let s:operator = "d"
	    let s:lastcount = strchars(deleted)
	    " BACKSPACEVSDEL
	    let motion = gcp < lastgcp ? "h" : "l"
	    let s:lastedit = ["opend", motion, 0]
	endif
    endif
    if has_insert
	call s:undo.add(1, "i", lenpre, inserted)
	if !has_delete
	    let s:lastedit = ["insert", 0, inscmd]
	    let s:lastcount = 1
	    let s:lastitext = inserted
	    call s:ModifyLastEdit(1)
	endif
    endif
    if has_delete && has_insert
	let s:operator = "c"
	let s:lastcount = strchars(deleted)
	let s:lastitext = inserted
	let motion = gcp < lastgcp ? "h" : "l"
	let s:lastedit = ["opend", motion, 0]
    endif
endfunc

" Undo: "{{{1
func! <sid>undo()
    return s:undo.do(s:getcount1())
endfunc

func! <sid>redo()
    return s:undo.redo(s:getcount1())
endfunc

" func! <sid>clru()
"     call s:undo.init()
"     return ""
" endfunc

func! <sid>cutundo()
    call s:undo.cut_older()
    return ""
endfunc

" an undo object without functionality
func! s:NewMockUndo()
    let obj = {}

    func! obj.init()
    endfunc

    func! obj.get_state()
	return {}
    endfunc

    func! obj.set_state(dict)
    endfunc

    func! obj.add(islast, dori, pos, str)
    endfunc

    func! obj.cut_older()
    endfunc

    func! obj.do(count1)
	call s:Warn('undo not implemented')
	return getcmdline()
    endfunc

    func! obj.redo(count1)
	call s:Warn('redo not implemented')
	return getcmdline()
    endfunc

    return obj
endfunc

" Misc: {{{1

func! s:CallOrFallback(func, default_func)
    try
	return call(a:func, [])
    catch
	call s:Warn()
	return call(a:default_func, [])
    endtry
endfunc

func! s:Input(prompt, ...)
    let varstore = {}
    for varname in s:stacked_vars
	if exists(varname)
	    let varstore[varname] = eval(varname)
	endif
    endfor
    let undostore = s:undo.get_state()
    call s:undo.init()
    call inputsave()
    let s:nested += 1
    try
	let depnum = s:nested+s:nested_off >= 2 ? "[".(s:nested+s:nested_off-1)."] " : ""
	let newtext = call("input", [depnum. a:prompt] + a:000)
	" let newtext = input(depnum. a:prompt, "x", 'custom,ConoUndoComplDeleted')
	" 2012 Feb 25 completion does not work, why?
    catch
	call s:Warn()
	" for now: Vim:Interrupt is like Esc, warn about errors
	let newtext = ""
    endtry
    let s:nested -= 1
    call inputrestore()
    call s:undo.set_state(undostore)
    for [varname, value] in items(varstore)
	exec "let" varname "= value"
	unlet value
    endfor
    return newtext
endfunc

func! s:PrefixPat(str)
    " {str}	non-empty string
    let ml = matchlist(a:str, '^\(.\)\(.*\)$')[1:2]
    call map(ml, 'escape(v:val, ''\.*$^~['')')
    if ml[1] =~ ']'
	let ml[1] = substitute(ml[1], ']', '[]]', 'g')
    endif
    return '^\C'. ml[0]. (ml[1]=="" ? "" : '\%['. ml[1]. ']')
endfunc

func! s:Reverse(str)
    return join(reverse(split(a:str, '\m')),'')
endfunc

func! s:SetReg(str, default_reg, regtype)
    let reg = s:register != '' ? s:register : a:default_reg
    let s:register = ''
    try
	" XXX How to make the unnamed register point to {reg}?
	call setreg(reg, '')		" check if {reg} can be used
	exec 'normal! "'. reg. 'yl'|	" workaround (we don't want this)
					" awful when on closed fold
	call setreg(reg, a:str, a:regtype)
    catch
	call s:Warn()
    endtry
endfunc

func! s:Warn(...)
    echohl WarningMsg
    if a:0 == 0
	redraw
	echomsg substitute(v:exception, '\C^Vim.\{-}:', '', '')
	sleep 1
    else
	echomsg a:1
	exec "sleep" (a:0>=2 ? a:2 : 300)."m"
    endif
    echohl None
endfunc

" experimental, after insert, modify remembered text for repeat
func! s:ModifyLastEdit(remember)
    " {remember}    if true, remember '\%(' vs. '\(' for next toggling of '\)'
    if s:lastitext =~ '^\\\=%\=($'
	if a:remember
	    let s:optional_percent = s:lastitext =~ '%($' ? '%' : ''
	endif
	let s:lastitext = substitute(s:lastitext, '^.\{-}\(\\\=\)%\=($', '\1)', '')
    elseif s:lastitext =~ '^\\\=)$'
	let s:lastitext = substitute(s:lastitext, '^.\{-}\(\\\=\))$', '\1'. s:optional_percent. '(', '')
    endif
endfunc
let s:optional_percent = ''

" API {{{1

" Usage: :cmap <expr> <C-O> conomode#Plug()
func! conomode#Plug()
    return "\<Plug>(Conomode)"
endfunc

" for conomode#map#Cmap()
func! conomode#Start()
    return s:sid_conomode
endfunc

" calling this function is like typing <C-G>u in Insert mode
func! conomode#BreakUndo()
    if getcmdtype() != "" && s:nested == 0
	call s:initcmdtype_for_undo()
	call s:try_continue_undo()
	" from <sid>rst_tm():
	let s:lastcmdline = getcmdline()
	let s:lastcmdpos = getcmdpos()
	let s:lastcmdtype = s:cmdtype
	unlet s:cmdtype
    endif
    return ""
endfunc

func! conomode#MakeLocalCmd()
    com! -nargs=* -complete=command ConomodeLocal <args>
endfunc

func! conomode#DelLocalCmd()
    delcom ConomodeLocal
endfunc

" debugging
func! conomode#Debug(...)
    " {a:1}	(boolean) if non-zero: enable, else: disable (default: 1)
    if a:0==0 || a:1
	let g:conomode_dbg_undo = s:undo
    else
	unlet! g:conomode_dbg_undo
    endif
endfunc

func! conomode#ReloadCmd()
    return 'source '. fnameescape(s:file)
endfunc

"func! conomode#UndoStat()
"    return printf('undo:%d/%d', s:undo.idx, len(s:undo.list))
"endfunc

func! conomode#SetUndo(instance)
    if exists("s:undo.get_state")
	call a:instance.set_state(s:undo.get_state())
    endif
    let s:undo = a:instance
endfunc

" this may or may not work:
func! conomode#GetUndoList()
    return copy(get(s:undo, 'list', [[]]))
endfunc

"}}}1

" Mappings:
" Entering: Cmdline-Normal mode {{{1
cmap		   <Plug>(Conomode)	<SID>(ComoMaybe)
cmap     <expr>    <SID>(ComoMaybe)	getcmdtype()=~"[=>]" ? "" : "<SID>(Conomode)"
" VALIDCMDTYPE
cnoremap <script>  <SID>(Conomode)	<SID>set_tm<CR><SID>:
cnoremap <silent>  <SID>set_tm		<C-R>=<sid>set_tm()

nmap <SID> <SID>
let s:sid_conomode = eval('"\'. maparg("<SID>"). '(Conomode)'. '"')
nunmap <SID>

" Simple Movement: h l (0) $ {{{1
cnoremap <script>   <SID>zero	  <SID>prezero<CR><C-B><SID>:
cnoremap <silent>   <SID>prezero  <C-R>=<sid>eatcount("0")
cnoremap <script>   <SID>:$	  <SID>predoll<CR><C-E><SID>:
cnoremap <silent>   <SID>predoll  <C-R>=<sid>eatcount("$")

cnoremap <expr><script> <SID>:h <sid>repinit("<Left>","h","^")."<SID>dorep<SID>:"
cnoremap <expr><script> <SID>:l <sid>repinit("<Right>","l","$")."<SID>dorep<SID>:"
cnoremap <expr><script> <SID>:k <sid>repinit("<Left>","k","^",&co)."<SID>dorep<SID>:"
cnoremap <expr><script> <SID>:j <sid>repinit("<Right>","j","$",&co)."<SID>dorep<SID>:"

cnoremap <expr><script> <SID>dorep <sid>rep("<SID>")
" there must not be a mapping for <SID> itself

" Motions: ^ f F t T ; , w b e W B E ` {{{1
cnoremap <script>   <SID>:^	<SID>cono^<CR><SID>:
cnoremap <silent>   <SID>cono^	<C-R>=<sid>move("caret")
cnoremap <script>   <SID>:<Bar>		<SID>cono<Bar><CR><SID>:
cnoremap <silent>   <SID>cono<Bar>	<C-R>=<sid>move("bar")

cnoremap <script>   <SID>:f	<SID>conof<CR><SID>:
cnoremap <silent>   <SID>conof	<C-R>=<sid>move_zap("f")
cnoremap <script>   <SID>:F	<SID>conoF<CR><SID>:
cnoremap <silent>   <SID>conoF	<C-R>=<sid>move_zap("F")
cnoremap <script>   <SID>:t	<SID>conot<CR><SID>:
cnoremap <silent>   <SID>conot	<C-R>=<sid>move_zap("t")
cnoremap <script>   <SID>:T	<SID>conoT<CR><SID>:
cnoremap <silent>   <SID>conoT	<C-R>=<sid>move_zap("T")
cnoremap <script>   <SID>:;	<SID>cono;<CR><SID>:
cnoremap <silent>   <SID>cono;	<C-R>=<sid>move("scolon")
cnoremap <script>   <SID>:,	<SID>cono,<CR><SID>:
cnoremap <silent>   <SID>cono,	<C-R>=<sid>move("comma")

cnoremap <script>   <SID>:w	<SID>conow<CR><SID>:
cnoremap <silent>   <SID>conow	<C-R>=<sid>move("w")
cnoremap <script>   <SID>:W	<SID>conoW<CR><SID>:
cnoremap <silent>   <SID>conoW	<C-R>=<sid>move("W")
cnoremap <script>   <SID>:b	<SID>conob<CR><SID>:
cnoremap <silent>   <SID>conob	<C-R>=<sid>move("b")
cnoremap <script>   <SID>:B	<SID>conoB<CR><SID>:
cnoremap <silent>   <SID>conoB	<C-R>=<sid>move("B")
cnoremap <script>   <SID>:e	<SID>conoe<CR><SID>:
cnoremap <silent>   <SID>conoe	<C-R>=<sid>move("e")
cnoremap <script>   <SID>:E	<SID>conoE<CR><SID>:
cnoremap <silent>   <SID>conoE	<C-R>=<sid>move("E")

cnoremap <script>   <SID>:%	<SID>cono%<CR><SID>:
cnoremap <silent>   <SID>cono%	<C-R>=<sid>move("percent")

cnoremap <script>   <SID>:`	<SID>cono`<CR><SID>:
cnoremap <silent>   <SID>cono`	<C-R>=<sid>move("backtick")

"" History: k j {{{1
"cnoremap <script>   <SID>:k	<SID>clru<Up><SID>:
"cnoremap <script>   <SID>:j	<SID>clru<Down><SID>:
"cnoremap <expr>	    <SID>clru	<sid>clru()

" Shortcuts: yy Y dd D x X cc C s S {{{1
cmap <SID>:yy	<SID>:y_
cmap <SID>:Y	<SID>:y$
cmap <SID>:dd	<SID>:d_
cmap <SID>:D	<SID>:d$
cmap <SID>:x	<SID>:dl
cmap <SID>:X	<SID>:dh
cmap <SID>:cc	<SID>:c_
cmap <SID>:C	<SID>:c$
" cmap <SID>:s	<SID>:dli   " not atomic, forgets count when repeating
cmap <SID>:s	<SID>:cl
cmap <SID>:S	<SID>:0d$i
cmap <SID>:g==	<SID>:g=_
cmap <SID>:g=g=	<SID>:g=_

" Put: P p {{{1
cnoremap <script>   <SID>:P	<SID>conoP<CR><SID>:
cnoremap <silent>   <SID>conoP	<C-\>e<sid>edit_put(1,'',0,-1)
cnoremap <script>   <SID>:p	<SID>conop<CR><SID>:
cnoremap <silent>   <SID>conop	<C-\>e<sid>edit_put(1,'',1,-1)

" Operators: d y c g= {{{1
cnoremap <script>   <SID>:d	<SID>conod<CR><SID>;
cnoremap <silent>   <SID>conod	<C-R>=<sid>setop("d")
cnoremap <script>   <SID>:y	<SID>conoy<CR><SID>;
cnoremap <silent>   <SID>conoy	<C-R>=<sid>setop("y")
cnoremap <script>   <SID>:g=	<SID>conog=<CR><SID>;
cnoremap <silent>   <SID>conog=	<C-R>=<sid>setop("eval")

cnoremap <script>   <SID>:c	<SID>conoc<CR><SID>;
cnoremap <silent>   <SID>conoc	<C-R>=<sid>setop("c")

" Simple Changes: r ~ {{{1
cnoremap <script>   <SID>:r	<SID>conor<CR><SID>:
cnoremap <silent>   <SID>conor	<C-\>e<sid>edit_r(1)
cnoremap <script>   <SID>:~	<SID>cono~<CR><SID>:
cnoremap <silent>   <SID>cono~	<C-\>e<sid>edit_tilde(1)

" Insert: I a A i o {{{1
cnoremap <script>   <SID>:I	<SID>conoI<CR><SID>rst_tm<CR>
cnoremap <silent>   <SID>conoI	<C-\>e<sid>insert_begin("I")
cnoremap <script>   <SID>:i	<SID>conoi<CR><SID>rst_tm<CR>
cnoremap <silent>   <SID>conoi	<C-R>=<sid>insert_begin("i")
cnoremap <script>   <SID>:a	<SID>conoa<CR><SID>rst_tm<CR>
cnoremap <silent>   <SID>conoa	<C-R>=<sid>insert_begin("a")
cnoremap <script>   <SID>:A	<SID>conoA<CR><SID>rst_tm<CR>
cnoremap <silent>   <SID>conoA	<C-R>=<sid>insert_begin("A")

" XXX R{text}<C-O>[count]. misbehaving, works like [count]cl{text}<CR>
cnoremap <script>   <SID>:R	<SID>conoi<CR><SID>rst_tm<CR><Insert>

cnoremap <script>   <SID>:o	<SID>conoo<CR><SID>:
cnoremap <silent>   <SID>conoo	<C-\>e<sid>insert(1,"o")

" Undo: u U {{{1
cnoremap <script>   <SID>:u	<SID>conou<CR><SID>:
cnoremap <silent>   <SID>conou	<C-\>e<sid>undo()
cnoremap <script>   <SID>:U	<SID>conoU<CR><SID>:
cnoremap <silent>   <SID>conoU	<C-\>e<sid>redo()

" Repeating: . {{{1
cnoremap <script>   <SID>:.	<SID>cono.<CR><SID>:
cnoremap <silent>   <SID>cono.	<C-\>e<sid>edit_dot()

" Count: 1 2 3 4 5 6 7 8 9 (0) {{{1
cnoremap <silent>   <SID>cono0	<C-R>=<sid>counta("0")
cnoremap <script>   <SID>:1	<SID>cono1<CR><SID>:
cnoremap <silent>   <SID>cono1	<C-R>=<sid>counta("1")
cnoremap <script>   <SID>:2	<SID>cono2<CR><SID>:
cnoremap <silent>   <SID>cono2	<C-R>=<sid>counta("2")
cnoremap <script>   <SID>:3	<SID>cono3<CR><SID>:
cnoremap <silent>   <SID>cono3	<C-R>=<sid>counta("3")
cnoremap <script>   <SID>:4	<SID>cono4<CR><SID>:
cnoremap <silent>   <SID>cono4	<C-R>=<sid>counta("4")
cnoremap <script>   <SID>:5	<SID>cono5<CR><SID>:
cnoremap <silent>   <SID>cono5	<C-R>=<sid>counta("5")
cnoremap <script>   <SID>:6	<SID>cono6<CR><SID>:
cnoremap <silent>   <SID>cono6	<C-R>=<sid>counta("6")
cnoremap <script>   <SID>:7	<SID>cono7<CR><SID>:
cnoremap <silent>   <SID>cono7	<C-R>=<sid>counta("7")
cnoremap <script>   <SID>:8	<SID>cono8<CR><SID>:
cnoremap <silent>   <SID>cono8	<C-R>=<sid>counta("8")
cnoremap <script>   <SID>:9	<SID>cono9<CR><SID>:
cnoremap <silent>   <SID>cono9	<C-R>=<sid>counta("9")

" Mark: m {{{1
cnoremap <script>   <SID>:m	<SID>conom<CR><SID>:
cnoremap <silent>   <SID>conom	<C-R>=<sid>set_mark()

" Register: " "{{{1
cmap		    <SID>:"	<SID>"
cmap		    <SID>"<Esc>	<SID>:
cmap <expr>	    <SID>"	<sid>get_regchar(). '<SID>:'

" Omap Motions: h l w W b B e E $ ^ {{{1
cnoremap <script>   <SID>;h	<SID>oconh<CR><SID>:
cnoremap <silent>   <SID>oconh	<C-\>e<sid>opend("h")
cnoremap <script>   <SID>;l	<SID>oconl<CR><SID>:
cnoremap <silent>   <SID>oconl	<C-\>e<sid>opend("l")
cnoremap <script>   <SID>;w	<SID>oconw<CR><SID>:
cnoremap <silent>   <SID>oconw	<C-\>e<sid>opend("w")
cnoremap <script>   <SID>;W	<SID>oconW<CR><SID>:
cnoremap <silent>   <SID>oconW	<C-\>e<sid>opend("W")
cnoremap <script>   <SID>;b	<SID>oconb<CR><SID>:
cnoremap <silent>   <SID>oconb	<C-\>e<sid>opend("b")
cnoremap <script>   <SID>;B	<SID>oconB<CR><SID>:
cnoremap <silent>   <SID>oconB	<C-\>e<sid>opend("B")
cnoremap <script>   <SID>;e	<SID>ocone<CR><SID>:
cnoremap <silent>   <SID>ocone	<C-\>e<sid>opend("e")
cnoremap <script>   <SID>;E	<SID>oconE<CR><SID>:
cnoremap <silent>   <SID>oconE	<C-\>e<sid>opend("E")
cnoremap <script>   <SID>;$	<SID>ocon$<CR><SID>:
cnoremap <silent>   <SID>ocon$	<C-\>e<sid>opend("dollar")
cnoremap <silent>   <SID>ocon0	<C-\>e<sid>opend("zero")
cnoremap <script>   <SID>;^	<SID>ocon^<CR><SID>:
cnoremap <silent>   <SID>ocon^	<C-\>e<sid>opend("caret")
cnoremap <script>   <SID>;<Bar>		<SID>ocon<Bar><CR><SID>:
cnoremap <silent>   <SID>ocon<Bar>	<C-\>e<sid>opend("bar")

cnoremap <script>   <SID>;%	<SID>ocon%<CR><SID>:
cnoremap <silent>   <SID>ocon%	<C-\>e<sid>opend("percent")

" special case
cnoremap <script>   <SID>;_	<SID>ocon_<CR><SID>:
cnoremap <silent>   <SID>ocon_	<C-\>e<sid>opend("_")

cnoremap <script>   <SID>;`	<SID>ocon`<CR><SID>:
cnoremap <silent>   <SID>ocon`	<C-\>e<sid>opend("backtick")

" Omap count: 1 2 3 4 5 6 7 8 9 (0) {{{1
cnoremap <silent>   <SID>ocnt0	<C-R>=<sid>countb("0")
cnoremap <script>   <SID>;1	<SID>ocnt1<CR><SID>;
cnoremap <silent>   <SID>ocnt1	<C-R>=<sid>countb("1")
cnoremap <script>   <SID>;2	<SID>ocnt2<CR><SID>;
cnoremap <silent>   <SID>ocnt2	<C-R>=<sid>countb("2")
cnoremap <script>   <SID>;3	<SID>ocnt3<CR><SID>;
cnoremap <silent>   <SID>ocnt3	<C-R>=<sid>countb("3")
cnoremap <script>   <SID>;4	<SID>ocnt4<CR><SID>;
cnoremap <silent>   <SID>ocnt4	<C-R>=<sid>countb("4")
cnoremap <script>   <SID>;5	<SID>ocnt5<CR><SID>;
cnoremap <silent>   <SID>ocnt5	<C-R>=<sid>countb("5")
cnoremap <script>   <SID>;6	<SID>ocnt6<CR><SID>;
cnoremap <silent>   <SID>ocnt6	<C-R>=<sid>countb("6")
cnoremap <script>   <SID>;7	<SID>ocnt7<CR><SID>;
cnoremap <silent>   <SID>ocnt7	<C-R>=<sid>countb("7")
cnoremap <script>   <SID>;8	<SID>ocnt8<CR><SID>;
cnoremap <silent>   <SID>ocnt8	<C-R>=<sid>countb("8")
cnoremap <script>   <SID>;9	<SID>ocnt9<CR><SID>;
cnoremap <silent>   <SID>ocnt9	<C-R>=<sid>countb("9")

" Omap Zap Motions: f F t T ; , {{{1
cnoremap <script>   <SID>;f	<SID>oconf<CR><SID>:
cnoremap <silent>   <SID>oconf	<C-\>e<sid>opend("f",1,"scolon")
cnoremap <script>   <SID>;F	<SID>oconF<CR><SID>:
cnoremap <silent>   <SID>oconF	<C-\>e<sid>opend("F",1,"scolon")
cnoremap <script>   <SID>;t	<SID>ocont<CR><SID>:
cnoremap <silent>   <SID>ocont	<C-\>e<sid>opend("t",1,"scolon")
cnoremap <script>   <SID>;T	<SID>oconT<CR><SID>:
cnoremap <silent>   <SID>oconT	<C-\>e<sid>opend("T",1,"scolon")
cnoremap <script>   <SID>;;	<SID>ocon;<CR><SID>:
cnoremap <silent>   <SID>ocon;	<C-\>e<sid>opend("scolon")
cnoremap <script>   <SID>;,	<SID>ocon,<CR><SID>:
cnoremap <silent>   <SID>ocon,	<C-\>e<sid>opend("comma")

" Goodies: c_CTRL-R_*, ^L {{{1
" non-vi, with undo, count, dot-repeat
cnoremap <script>   <SID>:<C-R>	<SID>cr"
cnoremap <script>   <SID>cr"*	<SID>CtlR*<CR><SID>:
cnoremap <silent>   <SID>CtlR*	<C-\>e<sid>edit_put(1,'*',0,0)
cmap		    <SID>cr"	<SID>rst_tm<SID><CR><C-R>

cnoremap <script>   <SID>:<C-L>	<Space><C-H><SID>:

cnoremap <script>   <SID>:gX	<C-R>=<sid>cutundo()<CR><SID>:

" Mode Switching: {{{1
cmap		    <SID>::	<SID>:ddi

" no map for "<SID>:<Esc>" makes <Esc> return to Normal mode immediately

cnoremap <script>   <SID>:	<SID>rst_tm<CR>
cnoremap <silent>   <SID>rst_tm <C-R>=<sid>rst_tm()
cnoremap	    <SID><CR>	<CR>

cmap		    <SID>;	<SID>:
cmap		    <SID>;<Esc> <SID>:

"}}}1

" Init: {{{
try
    call conomode#SetUndo(s:CallOrFallback(g:conomode_undo_maker, 's:NewMockUndo'))

    " Source Hook:
    if exists('g:conomode_source_hook')
	try
	    call nwo#gobi#Invoke(g:conomode_source_hook)
	catch
	    call s:Warn()
	endtry
    endif

finally
    let &cpo = s:cpo_sav
endtry

"}}}

" Modeline: {{{1
" vim:set ts=8 sts=4 sw=4 fdm=marker:
