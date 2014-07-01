" File:        util.vim
" Author:      ferreum (github.com/ferreum)
" Created:     2014-07-01
" Last Change: 2014-07-01
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

function! bufstack#util#list_mru(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   let bufs = []
   if !empty(stack.last)
      let current = stack.bufs[stack.index]
      let bufs = insert(filter(copy(stack.last), 'buflisted(v:val) && v:val != current'), current)
   endif
   if len(bufs) < max
      call extend(bufs, filter(copy(stack.bufs), 'buflisted(v:val) && index(bufs, v:val) < 0'))
   endif
   return bufs[:(max-1)]
endfunction

function! bufstack#util#list_bufs(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   return filter(copy(stack.bufs), 'buflisted(v:val)')[:(max-1)]
endfunction

function! bufstack#util#list_bufs_raw(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   return stack.bufs[:(max-1)]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
