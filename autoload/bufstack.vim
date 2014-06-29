" File:        bufstack.vim
" Author:      ferreum (github.com/ferreum)
" Created:     2014-06-29
" Last Change: 2014-06-29
" License:     MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

let s:save_cpo = &cpo
set cpo&vim

" Core: {{{1

function! s:buflist_insert(list, item, max) abort
   call insert(filter(a:list, 'v:val != a:item'), a:item)
   if len(a:list) > a:max
      call remove(a:list, a:max, len(a:list) - 1)
   endif
   return a:list
endfunction

function! bufstack#add_mru(bufnr) abort
   call s:buflist_insert(g:bufstack_mru, a:bufnr, g:bufstack_max_mru)
endfunction

function! bufstack#addvisited(stack, bufnr) abort
   call s:buflist_insert(a:stack.last, a:bufnr, g:bufstack_max)
endfunction

function! s:applylast_(stack) abort
   " move visited buffers to top of the stack
   let bufs = a:stack.bufs
   let last = a:stack.last
   call filter(bufs, 'index(last, v:val) < 0')
   let bufs = extend(last, bufs)
   if len(bufs) > g:bufstack_max
      call remove(bufs, g:bufstack_max, len(bufs) - 1)
   endif
   let a:stack.bufs = bufs
   let a:stack.last = []
endfunction

function! s:applyindex_(stack) abort
   if !empty(a:stack.last)
      call bufstack#addvisited(a:stack, a:stack.bufs[a:stack.index])
      let a:stack.index = 0
   endif
endfunction

function! bufstack#applylast(stack) abort
   call s:applyindex_(a:stack)
   call s:applylast_(a:stack)
endfunction

function! bufstack#maketop(stack, bufnr) abort
   call s:applyindex_(a:stack)
   call bufstack#addvisited(a:stack, a:bufnr)
   call s:applylast_(a:stack)
endfunction

function! s:initstack() abort
   let altwin = winnr('#')
   let w:bufstack = altwin >= 1 ? deepcopy(getwinvar(altwin, 'bufstack', {})) : {}
   if empty(w:bufstack)
      let w:bufstack.bufs = []
      let w:bufstack.last = []
      let w:bufstack.index = 0
   else
      call bufstack#applylast(w:bufstack)
   endif
   let w:bufstack.bufs = filter(copy(g:bufstack_mru), 'buflisted(v:val)')
endfunction

function! bufstack#get_stack() abort
   if !exists('w:bufstack')
      if buflisted(bufnr('%'))
         call bufstack#add_mru(bufnr('%'))
      endif
      call s:initstack()
   endif
   return w:bufstack
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
