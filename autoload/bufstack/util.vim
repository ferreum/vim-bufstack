" File:        util.vim
" Author:      ferreum (github.com/ferreum)
" Created:     2014-07-01
" Last Change: 2016-10-15
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

function! bufstack#util#is_listed(bufnr) abort
   return buflisted(a:bufnr) && getbufvar(a:bufnr, '&bufhidden', '') == ''
endfunction

function! bufstack#util#get_current_bufnr(...) abort
   let stack = a:0 ? a:1 : bufstack#get_stack()
   if empty(stack.bufs)
      return bufnr('%')
   elseif empty(stack.last)
      return stack.bufs[0]
   else
      return stack.bufs[stack.index]
   endif
endfunction

function! bufstack#util#list_mru(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   let bufs = []
   if !empty(stack.last)
      let current = stack.bufs[stack.index]
      let bufs = insert(filter(copy(stack.last), 'bufstack#util#is_listed(v:val) && v:val != current'), current)
   endif
   if len(bufs) < max
      call extend(bufs, filter(copy(stack.bufs), 'bufstack#util#is_listed(v:val) && index(bufs, v:val) < 0'))
   endif
   return bufs[:(max-1)]
endfunction

function! bufstack#util#list_bufs(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   return filter(copy(stack.bufs), 'bufstack#util#is_listed(v:val)')[:(max-1)]
endfunction

function! bufstack#util#list_bufs_raw(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   return stack.bufs[:(max-1)]
endfunction

function! bufstack#util#list_status_bufs(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max <= 0
      return []
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   if empty(stack.bufs)
      return []
   endif
   if !empty(stack.last)
      let current = stack.bufs[stack.index]
   else
      let current = stack.bufs[0]
   endif
   return filter(copy(stack.bufs), 'v:val == current || bufstack#util#is_listed(v:val)')[:(max-1)]
endfunction

function! bufstack#util#get_status_info(...) abort
   let max = a:0 >= 1 ? a:1 : 99999
   if max < 1
      let max = 1
   endif
   let stack = a:0 >= 2 ? a:2 : bufstack#get_stack()
   let bufs = stack.bufs
   if empty(stack.bufs)
      return {'current': -1, 'more': 0, 'near': []}
   endif
   if !empty(stack.last)
      let current = bufs[stack.index]
   else
      let current = bufs[0]
   endif
   " Add current here, because we want to show it even when unlisted.
   let near = [current]
   if max >= 1 && stack.index > 0
      for buf in bufs[:(stack.index - 1)]
         if bufstack#util#is_listed(buf)
            call insert(near, buf, -1)
         endif
      endfor
   endif
   if max >= 2
      for buf in bufs[(stack.index + 1):]
         if bufstack#util#is_listed(buf) && len(add(near, buf)) >= max
            break
         endif
      endfor
   endif
   if len(near) > max
      let more = len(near) - max
      call remove(near, 0, more - 1)
   else
      let more = 0
   endif
   return {'current': current, 'more': more, 'near': near}
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
