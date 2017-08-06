" File:         default.vim
" Created:      2017 Mar 20
" Last Change:  2017 Jun 04
" Version:      0.2
" Author:       Andy Wokula <anwoku@yahoo.de>
" License:      Vim License, see :h license

" Usage:
"   " vimrc:
"   :let conomode_undo_maker = 'conomode#undo#default#New'
"
"   " interactive:
"   :call conomode#SetUndo(conomode#undo#default#New())

" Notes:
" * for now, get_state() does not return default values -- we want to get
"   notified about errors

" History:
" 2017 Jun 04	BF: better init() immediately
" 2017 Mar 20	extracted here from autoload\conomode.vim

func! conomode#undo#default#New()
    let obj = copy(s:undo)
    call obj.init()
    return obj
endfunc

let s:undo = {}

func! s:undo.init()
    call self.set_state({})
endfunc

func! s:undo.get_state()
    return {"list": self.list, "idx": self.idx}
endfunc

func! s:undo.set_state(dict)
    let self.list = get(a:dict, 'list', [[]])
    let self.idx  = get(a:dict, 'idx', 0)
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

func! s:undo.cut_older()
    if self.idx >= 1
	call remove(self.list, 0, self.idx-1)
	let self.idx = 0
    endif
endfunc

func! s:undo.do(count1)
    " do undo, go backwards in the list
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

func! s:undo.redo(count1)
    let cmdl = getcmdline()
    let cnt = a:count1
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
	    " type == "m": just move the cursor
	    call setcmdpos(pos+1)
	    let self.idx += 1
	    let item = get(self.list, self.idx, [])
	endwhile
	let cnt -= 1
    endwhile
    return cmdl
endfunc

