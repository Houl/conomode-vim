" File:         map.vim
" Created:      2016 Feb 07
" Last Change:  2017 Jan 25
" Version:      0.3
" Author:       Andy Wokula <anwoku@yahoo.de>
" License:      Vim License, see :h license

func! conomode#map#Cmap(lhs, rhs)
    return printf('cmap <expr> %s getcmdtype()=~"[=>]" ? %s : conomode#Start().%s', a:lhs, string(a:lhs), string(a:rhs))
    " VALIDCMDTYPE
endfunc

func! conomode#map#Cmap1(lhs, rhs)
    return printf('cmap <expr> %s getcmdtype()=~"[=>]" \|\| (getcmdpos()==1 && getcmdline()=="") ? %s : conomode#Start().%s', a:lhs, string(a:lhs), string(a:rhs))
endfunc
