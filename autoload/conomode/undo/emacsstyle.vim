" File:         emacsstyle.vim
" Created:      2017 Mar 20
" Last Change:  2017 Jun 04
" Version:      0.2
" Author:       Andy Wokula <anwoku@yahoo.de>
" License:      Vim License, see :h license

" Usage:
"   " vimrc:
"   :let conomode_undo_maker = 'conomode#undo#emacsstyle#New'
"
"   " interactive:
"   :call conomode#SetUndo(conomode#undo#emacsstyle#New())

" History:
" 2017 Jun 04	BF: better init() immediately
" 2017 Mar 20	based on :FeatEdit conomode-emacs-style-undo

func! conomode#undo#emacsstyle#New()
    let obj = copy(s:undo)
    call obj.init()
    return obj
endfunc

let s:undo = {}

func! s:undo.init()
    call self.set_state({})
endfunc

func! s:undo.get_state()
    return {"list": self.list, "idx": self.idx, "undoing": get(self, "undoing", 0)}
endfunc

func! s:undo.set_state(dict)
    let self.list = get(a:dict, 'list', [[]])
    let self.idx  = get(a:dict, 'idx', 0)
    let self.undoing = get(a:dict, 'undoing', 0)
endfunc

func! s:undo.add(islast, dori, pos, str)
    let self.idx += 1
    call add(self.list, [a:dori, a:pos, a:str])
    if get(self, 'undoing', 0)
	let self.idx = len(self.list) - 1
	let self.undoing = 0
    endif
    if a:islast
	call self.stopseq()
    endif
endfunc

func! s:undo.stopseq()
    let self.idx += 1
    call add(self.list, [])
endfunc

func! s:undo.cut_older()
    if self.idx >= 1
	call remove(self.list, 0, self.idx-1)
	let self.idx = 0
    endif
endfunc

func! s:undo.do(count1)
    " do undo, go backwards in the list
    let self.undoing = 1
    let cmdl = getcmdline()
    let cnt = a:count1
    while cnt >= 1 && self.idx >= 1
	let self.idx -= 1
	let item = get(self.list, self.idx, [])
	while !empty(item)
	    let [type, pos, str] = item
	    if type == "d"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos)
		let cmdl = left. str. right
		call add(self.list, ["i", pos, str])
		let pos += strlen(str)
	    elseif type == "i"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos + strlen(str))
		let cmdl = left. right
		call add(self.list, ["d", pos, str])
	    else
		call add(self.list, ["m", pos, ""])
	    endif
	    call setcmdpos(pos+1)
	    let self.idx -= 1
	    let item = get(self.list, self.idx, [])
	endwhile
	call add(self.list, [])
	let cnt -= 1
    endwhile
    return cmdl
endfunc

func! s:undo.redo(count1)
    let cmdl = getcmdline()
    let cnt = a:count1
    while cnt >= 1 && exists("self.list[self.idx+1]")
	let self.idx += 1
	let item = get(self.list, self.idx, [])
	while !empty(item)
	    call remove(self.list, -1)
	    let [type, pos, str] = item
	    if type == "d"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos + strlen(str))
		let cmdl = left. right
	    elseif type == "i"
		let left = strpart(cmdl, 0, pos)
		let right = strpart(cmdl, pos)
		let cmdl = left. str. right
		let pos += strlen(str)
	    endif
	    " type == "m": just move the cursor
	    call setcmdpos(pos+1)
	    let self.idx += 1
	    let item = get(self.list, self.idx, [])
	endwhile
	call remove(self.list, -1)
	let cnt -= 1
    endwhile
    return cmdl
endfunc
