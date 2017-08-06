" Vim plugin -- Vi-style editing for the cmdline
" General: {{{1
" File:		conomode.vim
" Created:	2008 Sep 28
" Last Change:	2012 Jan 30
" Rev Days:	38
" Author:	Andy Wokula <anwoku@yahoo.de>
" Version:	0.6.1 (macro, undo)
" Credits:
"   inspired from a vim_use thread on vi-style editing in the bash (there
"   enabled with 'set -o vi').
"   Subject:  command line
"   Date:     25-09-2008

" CAUTION:	This script may crash older Vims now and then!  (buggy
"		getcmdline()?) -- fixed since Vim7.3

" Description: {{{1
"   Implements a kind of Normal mode ( "Cmdline-Normal mode" ) for the
"   Command line.  Great fun if   :h cmdline-window   gets boring ;-)

" Usage: {{{1
" - when in Cmdline-mode, press <C-O> to enter "Commandline-Normal mode"
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
"   input() version of i (versus i: accepts a count, recordable)
" - Repeating: .
"   repeatable commands: d r c ~ o
"   also: I i a A
" - Undo: u U
"   redo with "U" (to keep c_CTRL-R working); undo information survives mode
"   switching; undo is unlimited
" - Count: can be given for most commands
" - Macros: q @
"   q starts[/stops] recording, @ executes, no register involved
" - Shortcuts: yy Y dd D x X cc C s S
"   yy -> y_, Y -> y$, dd -> d_, D -> d$, x -> dl, X -> dh, cc -> c_,
"   C -> c$, s -> cl, S -> 0d$i
" - Misc: <C-L> - redraw the Cmdline, gX - cut undo (forget older entries)

" Incompatibilities: (some ...) {{{1
" - redo with "U" (instead of "<C-R>")
" - "q" and "@" don't ask for a register, "@" while recording a macro
"   immediately executes
" - "o" is alternate version of "i", no "O"
" - no "Beep" situation (yet) to interrupt macro execution

" Small Differences:
" - "e" jumps after the word, "$" jumps to EOL (after last char in the
"   line), "e" and "$" are exclusive
" - at EOL, "x", "dl", "dw" etc. do not go left to delete at least one
"   character
" - typing "dx" does "x", ignoring "d"; same for similar situations
" - "c", "r", "~": no undo step if old and new text are equal; "i": no undo
"   step if nothing inserted
" - "yy" yanks characterwise
" - "q" does not record into a register, data is stored in g:CONOMODE_RECBUF

" Notes: {{{1
" - strange: utf-8 characters are garbled by the mode indicator; press
"   Ctrl-L to redraw
" - how to find out which keys are mapped in the mode?
"	:ConomodemacroLocal cmap <SID>:
" - mapping <SID>:<BS> (<BS> = a key code expanding to several bytes)
"   doesn't work; probably this is related to a known Vim bug:
"	:h todo|/These two abbreviations don't give the same result:
" - manipulation of cmdline and cursor position uses getcmdline(),
"   c_CTRL-\_e, c_CTRL-R_=, getcmdpos(), setcmdpos()
" - ok: "3fx;;" -- do not remember the count for ";"
" - ok: "cw{text}<CR>5." -- "5." does "5cw{text}<CR>"

" TODO: {{{1
" - M we need a beep: when executing, if one of the recorded commands fails,
"   the rest of the commands should not be executed
" - M beep: or just do  :normal <C-C>  plus  feedkeys( <SID>: ) ?
" ? refactor s:count1?
" ? while recording, use input() for "i", "I", "a", "A"
" ? recursive <F4>
" - (non-vi) "c", "i": if the last inserted char is a parenthesis (and it is
"   the only one), then "." will insert the corresponding paren
" - support more registers, make '"adw' work
" - last-position jump, ``
" ? (non-vi) somehow enable Smartput??
" ? (from vile) "q" in Operator-pending mode records a motion
" - <F4>i{text}<F4> (or just {text}<F4>): starting with empty cmdline can't
"   be repeated
" - search commands "/", "?", "n", "N" for the cmd-history
" - make ":" work like in ctmaps.vim
" - zap to multi-byte char
"
" + count: [1-9][0-9]* enable zero after one non-zero
" + count with multiplication: 2d3w = 6dw
" + count: f{char}, F{char}; r{char}; undo; put
" + "c" is repeatable
" + BF compare old and new text case sensitive
" + BF for now, disable recursive <F4>
" + BF opend(), allow "c" on zero characters
" + qcfx^UFoo^M@ works!! (with somes "x"es in the line)
" + BF qc$q recorded <SID>ocondollar<CR> instead of <SID>ocon$<CR>
" + doop_c: no default text, instead add old text to input history
" + BF doop_c: escape chars in input string for use in mapping (?) - yes!
" + implement "i", "I" and "A" with input(), like "c"
" + no need longer need to type <C-U> in "c{motion}<C-U>{text}<CR>"
" + BF undo/redo is now recorded
" + BF doop_c, opend: c{motion} should leave the cursor after the change
" + after playing a macro, undo the recorded commands at once.
"   ! KISS: let "@" remember the undo-index (mac_begin); when finished with
"   playing, remove the []s back to that index
" + command "a": move right first
" + continuous undo (don't break undo when switching to Cmdline-mode)
" + multi-byte support (!): some commands moved bytewise, not characterwise
"   (Mbyte); noch was übersehen?
" + BF <F4>-recursion prevention did <C-R>= within <C-\>e (not allowed)
" + BF need two kinds of escaping, s:MapEscape()
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
" + NF: "gX" - cut older undo states
" + BF: <SID>:<C-R>* now recorded

" }}}

" Checks: {{{1
if exists("loaded_conomode")
    finish
endif
let loaded_conomode = 1

if v:version < 700
    echomsg "conomode: you need at least Vim 7.0"
    finish
endif

let s:cpo_sav = &cpo
set cpo&vim

if &cedit == "\<C-X>"
    echomsg "Conomode: Please do :set cedit& (only a warning)."
    " the user's new key for 'cedit' may come in the way
endif

" Config: {{{1
" if non-zero, add a few keys for Cmdline-mode
if !exists("g:conomode_emacs_keys")
    let g:conomode_emacs_keys = 0
endif

" Some Local Variables: {{{1
let s:zaprev = {"f": "F", "F": "f", "t": "T", "T": "t"}
if !exists("s:undo")
    let s:undo = {}
endif
if !exists("s:quitnormal")
    let s:quitnormal = 1
endif
if !exists("s:undostore")
    let s:undostore = {}
endif

" DEBUG:
let g:conomode_dbg_undo = s:undo

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

let s:cmdrev = {
    \  "caret": "^", "scolon": ";", "comma": ",", "dollar": "$"
    \, "percent": "%", "bar": "|"
    \, "put0-1": "P", "put1-1": "p", "put00": "<C-R>*" }

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

func! s:getpos_w()
    return s:forward_word("w", s:count1)
endfunc

func! s:getpos_W()
    return s:forward_word("W", s:count1)
endfunc

func! s:getpos_e()
    return s:forward_word("e", s:count1)
endfunc

func! s:getpos_E()
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

func! s:getpos_b()
    return s:backward_word("b", s:count1)
endfunc

func! s:getpos_B()
    return s:backward_word("B", s:count1)
endfunc

func! s:getpos_h()
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

func! s:getpos_l()
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

func! s:getpos_dollar()
    return strlen(getcmdline())
endfunc

func! s:getpos_0()
    return 0
endfunc

func! s:getpos_caret()
    return match(getcmdline(), '\S')
endfunc

" jump to matching paren
func! s:getpos_percent()
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

func! s:getpos_bar()
    let cmdl = getcmdline()
    let pos = byteidx(cmdl, s:count1-1)
    if pos == -1
	return strlen(cmdl)
    else
	return pos
    endif
endfunc

" Getzappos: {{{1
func! s:getzappos(zapcmd, ...)
    let cnt = s:count1
    if a:0 == 0
	if !s:from_mapping
	    call inputsave()
	    let aimchar = nr2char(getchar())
	    call inputrestore()
	else
	    let aimchar = nr2char(getchar())
	endif
	let s:lastzap = [a:zapcmd, aimchar]
	if s:recording
	    " call s:rec_chars(cnt, a:zapcmd.aimchar)
	    if s:zapmode == "n"
		let reczap = "<C-X>&<SID>cono". a:zapcmd
	    else
		let reczap = "<C-X>&<SID>ocon". a:zapcmd
	    endif
	    if s:zapmode == "o" && s:operator == "c"
		let s:rec_op_c = reczap."<CR>". s:MapEscape(aimchar)
	    else
		call s:rec_chars(cnt, reczap."<CR>". s:MapEscape(aimchar)."<SID>:")
	    endif
	endif
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

func! s:getpos_f()
    return s:getzappos("f")
endfunc

func! s:getpos_F()
    return s:getzappos("F")
endfunc

func! s:getpos_t()
    return s:getzappos("t")
endfunc

func! s:getpos_T()
    return s:getzappos("T")
endfunc

func! s:getpos_scolon()
    if exists("s:lastzap")
	return s:getzappos(s:lastzap[0], s:lastzap[1])
    else
	return getcmdpos()-1
    endif
endfunc

func! s:getpos_comma()
    if exists("s:lastzap")
	return s:getzappos(s:zaprev[s:lastzap[0]], s:lastzap[1])
    else
	return getcmdpos()-1
    endif
endfunc

" Move: {{{1
func! <sid>move(motion)
    let s:count1 = s:getcount1()
    call setcmdpos(1 + s:getpos_{a:motion}())
    call s:rec_chars(s:count1, a:motion)
    return ""
endfunc

func! <sid>move_zap(zapcmd)
    let s:count1 = s:getcount1()
    let s:zapmode = "n"
    call setcmdpos(1 + s:getzappos(a:zapcmd))
    return ""
endfunc

" Put: {{{1
func! <sid>edit_put(mode, reg, gcpoff, endoff)
    let coff = a:gcpoff
    if a:mode == 1
	" limit count to 500
	let cnt = min([s:getcount1(),500])
	let s:lastedit = ["edit_put", 0, a:reg, coff, a:endoff]
	let s:lastcount = cnt
	call s:rec_chars(cnt, "put". a:gcpoff. a:endoff)
    else
	let cnt = s:lastcount
    endif
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()
    if coff == 1 && cmdl[gcp] == ""
	let coff = 0
    endif
    let boff = coff==0 ? 0 : matchend(strpart(cmdl, gcp, 8), '.')
    let ins = repeat(getreg(a:reg), cnt)
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
	if !s:from_mapping
	    call inputsave()
	    let replchar = nr2char(getchar())
	    call inputrestore()
	else
	    let replchar = nr2char(getchar())
	endif
	let s:lastedit = ["edit_r", 0, replchar]
	let s:lastcount = cnt
	" we must have that damn replchar BEFORE the next <SID>:
	call s:rec_chars(cnt, "<C-X>&<SID>conor<CR>".s:MapEscape(replchar)."<SID>:")
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
	call s:rec_chars(cnt, "~")
    else
	let cnt = s:lastcount
    endif
    let gcp = getcmdpos()-1
    let cmdl = getcmdline()
    let ripos = matchend(cmdl, '.\{1,'.cnt.'}', gcp)
    if ripos >= 1
	let mid = cmdl[gcp : ripos-1]
	" let newmid = substitute(mid, '\(\u\)\|\(\l\)', '\l\1\u\2', 'g')
	let newmid = substitute(mid, '\k', '\=toupper(submatch(0))==#submatch(0) ? tolower(submatch(0)) : toupper(submatch(0))', 'g')
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
    let s:beep = 0
    call s:rec_chars("", a:op)
    return ""
endfunc

func! s:doop_d(str, pos, rep)
    let @@ = a:str
    call s:undo.add(1, "d", a:pos, a:str)
    call setcmdpos(a:pos + 1)
    return ""
endfunc

func! s:doop_y(str, pos, ...)
    let @@ = a:str
    call setcmdpos(a:pos + 1)
    return a:str
endfunc

" Insert: {{{1
func! s:doop_c(str, pos, rep)
    if s:beep && !s:from_mapping
	return a:str
    endif
    let @@ = a:str
    if !a:rep
	if !s:from_mapping
	    call histadd("@", a:str)
	    call inputsave()
	    let newtext = input("Change into:")
	    call inputrestore()
	else
	    let newtext = input("", a:str)
	endif
	let s:lastitext = newtext
	if s:recording
	    call s:rec_chars(s:count1, s:rec_op_c."<C-U>".s:MapEscape(newtext,"v")."<CR><SID>:")
	endif
    else
	let newtext = s:lastitext
    endif
    if s:beep
	return a:str
    endif
    if a:str !=# newtext
	call s:undo.add(0, "d", a:pos, a:str)
	call s:undo.add(1, "i", a:pos, newtext)
    endif
    call setcmdpos(a:pos+1 + strlen(newtext))
    return newtext 
endfunc

func! <sid>insert(mode, cmd)
    if a:mode == 1
	let cnt = s:getcount1()
	let s:lastedit = ["insert", 0, a:cmd]
	let s:lastcount = cnt
	if !s:from_mapping
	    call inputsave()
	    let newtext = input(a:cmd==?"a" ? "Append:" : "Insert:")
	    call inputrestore()
	else
	    let newtext = input("")
	endif
	let s:lastitext = newtext
	if s:recording
	    call s:rec_chars(cnt, a:cmd. "<C-X>&". s:MapEscape(newtext,"v"). "<CR><SID>:")
	    " faced a crash without <C-X>(eat) (and mapesc)
	endif
    else
	let cnt = s:lastcount
	let newtext = s:lastitext
    endif
    let cmdl = getcmdline()
    if newtext != "" || a:cmd ==# "I"
	if a:cmd ==# "I"
	    let iwhite = matchstr(cmdl, '^[ \t:]*')
	    if iwhite == "" && newtext == ""
		return cmdl
	    endif
	    let gcp = 0
	    call s:undo.add(0, "d", gcp, iwhite)
	    let cmdl = strpart(cmdl, strlen(iwhite))
	elseif a:cmd ==# "a"
	    let gcp = matchend(cmdl, '^.\=', getcmdpos()-1)
	elseif a:cmd ==# "A"
	    let gcp = strlen(cmdl)
	else
	    let gcp = getcmdpos()-1
	endif
	let resulttext = repeat(newtext, cnt)
	call s:undo.add(1, "i", gcp, resulttext) 
	call setcmdpos(gcp+1 + strlen(resulttext))
	return strpart(cmdl, 0, gcp). resulttext. strpart(cmdl, gcp)
    else
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
	if s:recording
	    if s:operator == "c"
		" just without trailing "<SID>:"
		let mot = get(s:cmdrev, a:motion, a:motion)
		let s:rec_op_c = "<C-X>&<SID>ocon".mot."<CR>"
	    else
		call s:rec_chars(s:count1, a:motion)
	    endif
	endif
    elseif a:1 == 1
	" zap motion, a:0 == 2
	let s:count1 = s:getcount1()
	let s:lastedit = ["opend", a:2, 0]
	let s:lastcount = s:count1
	let s:zapmode = "o"
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
	let tarpos = s:getpos_dollar()
    else
	let tarpos = s:getpos_{motion}()
    endif

    let cmdl = getcmdline()
    if gcp < tarpos
	let [pos1, pos2] = [gcp, tarpos+s:incloff]
    elseif tarpos < gcp
	let [pos1, pos2] = [tarpos, gcp+s:incloff]
    elseif s:operator == "c"
	" op c must accept everything to always eat ^U and ^M from rec
	let [pos1, pos2] = [gcp, gcp+s:incloff]
    else
	return cmdl
    endif

    let cmdlpart = strpart(cmdl, pos1, pos2-pos1)
    let newpart = s:doop_{s:operator}(cmdlpart, pos1, isrep)

    return strpart(cmdl,0,pos1). newpart. cmdl[pos2 :]
endfunc

" Repeat: {{{1
func! <sid>edit_dot()
    let cnt = s:getcount()
    call s:rec_chars(cnt, ".")
    if exists("s:lastedit")
	if cnt > 0
	    let s:lastcount = cnt
	endif
	return call("s:".s:lastedit[0], s:lastedit[1:])
    else
	return getcmdline()
    endif
endfunc

func! <sid>macro_rec()
    let s:counta = ""
    let s:countb = ""
    cmap <SID>:0 <SID>zero
    if !s:recording
	let s:recbuf = ""
	let s:recording = 1
	" call s:undo.mac_begin()
	call s:Warn("START recording")
    else
	" call s:undo.mac_end()
	let s:recording = 0
	let g:CONOMODE_RECBUF = s:recbuf
	call s:Warn("STOP recording")
    endif
    return ""
endfunc

" execute macro: duplicate macro count times, size limit=1000
func! <sid>macro_exec()
    if s:recording
	call s:undo.mac_end()
	let s:recording = 0
	let g:CONOMODE_RECBUF = s:recbuf
    endif
    let cnt = s:getcount1()
    if s:recbuf != ""
	let reclen = strlen(s:recbuf)
	if reclen * cnt > 1000
	    let cnt = max([1000 / reclen, 1])
	endif
	exec "cnoremap <script> <SID>macro_keys <SID>:".repeat(s:recbuf, cnt)
    else
	cnoremap <script> <SID>macro_keys <SID>:
    endif
    call s:undo.mac_begin()
    let s:from_mapping = 1
    return ""
endfunc

" special keys must be keycodes; a:1 - mode char : or ;
" sometimes we extra-check s:recording before calling this func, sometimes
" not
func! s:rec_chars(count1, str)
    if s:recording
	let str = get(s:cmdrev, a:str, a:str)
	let s:recbuf .= (a:count1>1 ? a:count1 : ""). str
    endif
endfunc

func! <sid>mapoff()
    call s:undo.mac_end()
    let s:from_mapping = 0
    return ""
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
    if s:recording
	call s:rec_chars(1, a:key)
    endif
    return ""
endfunc

" duplicate a basic motion count times
func! <sid>repinit(key, reckey, stopcond, ...)
    let cnt = s:getcount1()*(a:0 >= 1 ? a:1 : 1)
    if s:recording
	call s:rec_chars("", repeat(a:reckey, cnt))
    endif
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

" Init: (more local variables) {{{1
func! <sid>set_tm()
    if s:quitnormal
	let s:tm_sav = &tm
	set timeoutlen=60000
    endif
    let s:quitnormal = 0
    let s:counta = ""
    let s:countb = ""
    call s:undo.initcmdtype()
    call s:try_continue_undo()
    let s:recording = 0
    let s:recbuf = exists("g:CONOMODE_RECBUF") ? g:CONOMODE_RECBUF : ""

    " started conomode from a mapping? - commands with user input (r c f)
    " don't work, they will always query the user; but we can handle
    " 'internal' 'mappings':
    let s:from_mapping = 0
    " or check getchar(1) ?

    cmap <SID>:0 <SID>zero
    cnoremap <script> <SID>;0 <SID>ocon0<CR><SID>:
    return ""
endfunc

func! <sid>rst_tm()
    let &tm = s:tm_sav
    let s:quitnormal = 1
    call s:undo.setlastcmdline(getcmdline())
    let s:lastcmdtype = s:cmdtype
    unlet s:cmdtype
    return ""
endfunc

" a friend of s:undo; to be called *after* s:undo.initcmdtype()
func! s:try_continue_undo()
    if !has_key(s:undo, "lastcmdline")
	return
    endif
    let lastcmdl = s:undo.lastcmdline
    let cmdl = getcmdline()
    if cmdl ==# lastcmdl
	return
    endif

    let patL = matchlist(lastcmdl, '^\(.\)\(.*\)$')[1:2]

    if empty(patL)
	let isfinal = cmdl == ""
	if lastcmdl != ""
	    call s:undo.add(isfinal, "d", 0, lastcmdl)
	endif
	if !isfinal
	    call s:undo.add(1, "i", 0, cmdl)
	    " enable "." for short pieces (with arbit. limit)
	    if strlen(cmdl) <= 40
		let s:lastedit = ["insert", 0, "i"]
		let s:lastcount = 1
		let s:lastitext = cmdl
	    endif
	endif
	return
    endif

    call map(patL, 'escape(v:val, ''\.*$^~['')')
    let forw_pat = '^\C'. patL[0]. (patL[1]=="" ? "" : '\%['. patL[1]. ']')

    let com_prefix = matchstr(cmdl, forw_pat)
    let lenpre = strlen(com_prefix)
    let cmdlrest = strpart(cmdl, lenpre)

    let lastcmdlrest = strpart(lastcmdl, lenpre)
    if lastcmdlrest =~ '.'
	let revlastcmdlrest = join(reverse(split(lastcmdlrest, '\m')),'')
	let patL = matchlist(revlastcmdlrest, '^\(.\)\(.*\)$')[1:2]
	call map(patL, 'escape(v:val, ''\.*$^~['')')
	let back_pat = '^\C'. patL[0]. (patL[1]=="" ? "" : '\%['. patL[1]. ']')

	let com_suffix = matchstr(join(reverse(split(cmdlrest, '\m')),''), back_pat)
	let lensuf = strlen(com_suffix)
    else
	let com_suffix = ""
	let lensuf = 0
    endif

    let deleted = strpart(lastcmdl, lenpre, strlen(lastcmdl)-lensuf-lenpre)
    let inserted = strpart(cmdl, lenpre, strlen(cmdl)-lensuf-lenpre)

    let has_delete = deleted != ""
    let has_insert = inserted != ""
    let partial_edit = lenpre >= 1 || lensuf >= 1

    if has_delete
	call s:undo.add(!has_insert, "d", lenpre, deleted) 
    endif
    if has_insert

	" detection is ambigious, prefer a match left from the cursor
	let gcp = getcmdpos()-1
	let lenins = strlen(inserted)
	if gcp >= lenins && gcp < lenpre + lenins
	    " length of inserted prefix / suffix
	    let lip = gcp - lenpre
	    let lis = lenins - lip
	    let altins = strpart(inserted, lip, lis). strpart(inserted, 0, lip)
	    if strpart(cmdl, gcp-lenins, lenins) ==# altins
		let inserted = altins
		let lenpre -= lis
		" let lensuf += lis
	    endif
	endif

	call s:undo.add(1, "i", lenpre, inserted)
	if partial_edit && !has_delete
	    let s:lastedit = ["insert", 0, "i"]
	    let s:lastcount = 1
	    let s:lastitext = inserted
	endif
    endif
endfunc

" Undo: "{{{1
func! <sid>undo()
    if s:recording
	call s:rec_chars(s:getcount1(), "u")
    endif
    return s:undo.do()
endfunc

func! <sid>redo()
    if s:recording
	call s:rec_chars(s:getcount1(), "U")
    endif
    return s:undo.redo()
endfunc

" func! <sid>clru()
"     call s:undo.init()
"     return ""
" endfunc

func! <sid>cutundo()
    let undo = s:undo
    if undo.idx >= 1
	call remove(undo.list, 0, undo.idx-1)
	let undo.idx = 0
    endif
    return ""
endfunc

func! s:undo.init()
    let self.list = [[]]
    let self.idx = 0
    if has_key(self, "lastcmdline")
	unlet self.lastcmdline
    endif
endfunc

func! s:undo.initcmdtype()
    let s:cmdtype = tr(getcmdtype(), '?', '/')
    if !exists("s:lastcmdtype")
	call self.init()
	return
    elseif s:cmdtype == s:lastcmdtype
	unlet s:lastcmdtype
	return
    endif
    let s:undostore[s:lastcmdtype] = {
	\ "list": self.list,
	\ "idx": self.idx,
	\ "lastcmdline": self.lastcmdline }
    if has_key(s:undostore, s:cmdtype)
	call extend(self, s:undostore[s:cmdtype], "force")
    else
	call self.init()
    endif
    unlet s:lastcmdtype
endfunc

func! s:undo.setlastcmdline(str)
    let self.lastcmdline = a:str
endfunc

func! s:undo.add(islast, dori, pos, str)
    let self.idx += 1
    call insert(self.list, [a:dori, a:pos, a:str], self.idx)
    if a:islast
	call self.stopseq()
    endif
endfunc

func! s:undo.stopseq()
    let self.idx += 1
    call insert(self.list, [], self.idx)
    if exists("self.list[self.idx+1]")
	call remove(self.list, self.idx+1, -1)
    endif
endfunc

func! s:undo.mac_begin()
    let self.mac_idx = self.idx
endfunc

func! s:undo.mac_end()
    if exists("self.mac_idx")
	let idx = self.idx - 1
	while idx > self.mac_idx
	    if empty(self.list[idx])
		call remove(self.list, idx)
		let self.idx -= 1
	    endif
	    let idx -= 1
	endwhile
	unlet self.mac_idx
    endif
endfunc

func! s:undo.do()
    " do undo, go backwards in the list
    let cmdl = getcmdline()
    let cnt = s:getcount1()
    while cnt >= 1 && self.idx >= 1
	let self.idx -= 1
	let item = get(self.list, self.idx, [])
	while !empty(item)
	    let [type, pos, str] = item
	    if type == "d"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos)
		let cmdl = left. str. right
	    elseif type == "i"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos + strlen(str))
		let cmdl = left. right
	    endif
	    call setcmdpos(pos+1)
	    let self.idx -= 1
	    let item = get(self.list, self.idx, [])
	endwhile
	let cnt -= 1
    endwhile
    return cmdl
endfunc

func! s:undo.redo()
    let cmdl = getcmdline()
    let cnt = s:getcount1()
    while cnt >= 1 && exists("self.list[self.idx+1]")
	let self.idx += 1
	let item = get(self.list, self.idx, [])
	while !empty(item)
	    let [type, pos, str] = item
	    if type == "d"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos + strlen(str))
		let cmdl = left. right
	    elseif type == "i"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos)
		let cmdl = left. str. right
	    endif
	    call setcmdpos(pos+1)
	    let self.idx += 1
	    let item = get(self.list, self.idx, [])
	endwhile
	let cnt -= 1
    endwhile
    return cmdl
endfunc

" Misc: {{{1
func! s:Warn(...)
    echohl WarningMsg
    if a:0 == 0
	redraw
	echon matchstr(v:exception, ':\zs.*')
	sleep 1
    else
	echon a:1
	exec "sleep" (a:0>=2 ? a:2 : 300)."m"
    endif
    echohl None
endfunc

let s:esctbl = {
    \ "|": "<Bar>", "<": "<lt>", "v|": "<Bar>", "v<": "<lt>",
    \ "\r": '<CR>', "\n": '<NL>', "\e": '<Esc>',
    \ "v\r": '<C-V><CR>', "v\n": '<C-V><NL>', "v\e": '<C-V><Esc>'}
let s:escpat = '[|<[:cntrl:]]'

" Two kinds of escaping:
" "":	r|   -> r<Bar>      ,  r^M   -> r<CR>
" "v":	c|^[ -> c<Bar><Esc> ,  c^M^[ -> c<C-V><CR><Esc>

func! s:MapEscape(str, ...)
    " a:1   "" or "v" -- two kinds of escaping
    if a:str =~ s:escpat
	let vp = a:0>=1 ? a:1 : ""
	let str = substitute(a:str, s:escpat, '\=get(s:esctbl, vp. submatch(0), " O.o ")', 'g')
	return str
    else
	return a:str
    endif
endfunc

" func! <sid>exec(cmd)
"     try|exec a:cmd|catch|call s:Warn()|endtry
"     return ""
" endfunc

"}}}1

" Mappings:
" Entering: Cmdline-Normal mode {{{1
if !hasmapto("<Plug>(Conomode)", "c")
    cmap <C-O> <Plug>(Conomode)
    " was <F4> in earlier versions
endif

cmap		   <Plug>(Conomode)	<SID>(Como)
cmap     <expr>    <SID>(Como)		getcmdtype()=~'[=>@]' ? "" : "<SID>(ComoProceed)"
cnoremap <script>  <SID>(ComoProceed)	<SID>set_tm<CR><SID>:
cnoremap <silent>  <SID>set_tm		<C-R>=<sid>set_tm()

" Cmdline Mode Shortcuts: {{{1

" FIXME <C-W> inserts "dbi" when used with input(); solution: allow for
" recursion (keep mappings simple); problem: <C-\>e / <C-R>= can't be nested

if g:conomode_emacs_keys
    " bash-like <C-W> <C-Y> in vim command-line mode, a few Emacs shortcuts
    cmap <C-W>  <SID>(Como)dbi
    cmap <C-Y>  <SID>(Como)Pa
endif

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

" Motions: ^ f F t T ; , w b e W B E {{{1
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

" Put: P p {{{1
cnoremap <script>   <SID>:P	<SID>conoP<CR><SID>:
cnoremap <silent>   <SID>conoP	<C-\>e<sid>edit_put(1,'"',0,-1)
cnoremap <script>   <SID>:p	<SID>conop<CR><SID>:
cnoremap <silent>   <SID>conop	<C-\>e<sid>edit_put(1,'"',1,-1)

" Operators: d y c {{{1
cnoremap <script>   <SID>:d	<SID>conod<CR><SID>;
cnoremap <silent>   <SID>conod	<C-R>=<sid>setop("d")
cnoremap <script>   <SID>:y	<SID>conoy<CR><SID>;
cnoremap <silent>   <SID>conoy	<C-R>=<sid>setop("y")

cnoremap <script>   <SID>:c	<SID>conoc<CR><SID>;
cnoremap <silent>   <SID>conoc	<C-R>=<sid>setop("c")

" Simple Changes: r ~ {{{1
cnoremap <script>   <SID>:r	<SID>conor<CR><SID>:
cnoremap <silent>   <SID>conor	<C-\>e<sid>edit_r(1)
cnoremap <script>   <SID>:~	<SID>cono~<CR><SID>:
cnoremap <silent>   <SID>cono~	<C-\>e<sid>edit_tilde(1)

" Insert: I o a A i {{{1
cnoremap <script>   <SID>:I	<SID>cono^<CR><SID>rst_tm<CR>
cmap		    <SID>:i	<SID>rst_tm<SID><CR>
cnoremap <script>   <SID>:o	<SID>conoi<CR><SID>:
cnoremap <silent>   <SID>conoi	<C-\>e<sid>insert(1,"o")
cnoremap <script>   <SID>:a	<Right><SID>rst_tm<CR>
cnoremap <script>   <SID>:A	<End><SID>rst_tm<CR>

" Undo: u U {{{1
cnoremap <script>   <SID>:u	<SID>conou<CR><SID>:
cnoremap <silent>   <SID>conou	<C-\>e<sid>undo()
cnoremap <script>   <SID>:U	<SID>conoU<CR><SID>:
cnoremap <silent>   <SID>conoU	<C-\>e<sid>redo()

" Repeating: . q Q @ {{{1
cnoremap <script>   <SID>:.	<SID>cono.<CR><SID>:
cnoremap <silent>   <SID>cono.	<C-\>e<sid>edit_dot()
cnoremap <script>   <SID>:q	<SID>conoq<CR><SID>:
cnoremap <silent>   <SID>conoq	<C-R>=<sid>macro_rec()
cmap		    <SID>:@	<SID>cono@a<SID>macro_keys<C-X>(mapoff)<SID>cono@b
cnoremap <silent>   <SID>cono@a	<C-R>=<sid>macro_exec()<CR>
cnoremap <silent>   <SID>:<C-X>(mapoff)	<C-R>=<sid>mapoff()
cnoremap <script>   <SID>cono@b	<CR><SID>:
" <C-X>(eat) changed into &
cnoremap	    <SID>:<C-X>&  <Nop>
cnoremap	    <SID>;<C-X>&  <Nop>
" same bug as with '<SID>:<BS>': '<SID>:<C-X>(mapoff)' works, but
" '<SID>:<SID>mapoff' not; this workaround is dirty: <C-X>& typed by the
" user bypasses cleanup

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
cnoremap <silent>   <SID>ocon0	<C-\>e<sid>opend("0")
cnoremap <script>   <SID>;^	<SID>ocon^<CR><SID>:
cnoremap <silent>   <SID>ocon^	<C-\>e<sid>opend("caret")
cnoremap <script>   <SID>;<Bar>		<SID>ocon<Bar><CR><SID>:
cnoremap <silent>   <SID>ocon<Bar>	<C-\>e<sid>opend("bar")

cnoremap <script>   <SID>;%	<SID>ocon%<CR><SID>:
cnoremap <silent>   <SID>ocon%	<C-\>e<sid>opend("percent")

" special case
cnoremap <script>   <SID>;_	<SID>ocon_<CR><SID>:
cnoremap <silent>   <SID>ocon_	<C-\>e<sid>opend("_")

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
" non-vi, with undo, count, dot-repeat, recording
cnoremap <script>   <SID>:<C-R>	<SID>"
cnoremap <script>   <SID>"*	<SID>CtlR*<CR><SID>:
cnoremap <silent>   <SID>CtlR*	<C-\>e<sid>edit_put(1,"*",0,0)
cmap		    <SID>"	<SID>rst_tm<SID><CR><C-R>

" cnorem <script>   <SID>:<C-L>	<C-R>=<sid>exec("redraw")<CR><SID>:
cnoremap <script>   <SID>:<C-L>	<Space><C-H><SID>:

cnoremap <script>   <SID>:gX	<C-R>=<sid>cutundo()<CR><SID>:

" Mode Switching: {{{1
" From Cmdline-Normal mode 
" to Cmdline mode (start over)
cmap		    <SID>::	<SID>:dd<C-X>&<SID>rst_tm<SID><CR>

" no map for "<SID>:<Esc>" makes <Esc> return to Normal mode immediately
" cmap		    <SID>:<CR>	<SID>rst_tm<SID><CR><CR>

" to Cmdline mode (key not mapped -> make <SID>: do nothing)
cnoremap <script>   <SID>:	<SID>rst_tm<CR>
cnoremap <silent>   <SID>rst_tm <C-R>=<sid>rst_tm()
cnoremap	    <SID><CR>	<CR>

" Cmdline-Omap mode to Cmdline-Normal mode (implicit)
cmap		    <SID>;	<SID>:
" maybe:
cmap		    <SID>;<Esc> <SID>:

"}}}1

" DEBUG:
com! -nargs=* -complete=command ConomodeLocal <args>

" Modeline: {{{1
let &cpo = s:cpo_sav
" vim:set ts=8 sts=4 sw=4 fdm=marker:
