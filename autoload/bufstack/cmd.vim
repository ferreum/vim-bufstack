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

" Util: {{{1

function! s:windo(cmd, ...) abort
   let o_win = winnr()
   try
      windo call call(a:cmd, a:000)
   finally
      exe o_win . 'wincmd w'
   endtry
endfunction

function! s:tabwindo(cmd, ...) abort
   let o_tab = tabpagenr()
   let args = [a:cmd] + a:000
   try
      tabdo call call('s:windo', args)
   finally
      exe 'tabp' o_tab
   endtry
endfunction

" Core: {{{1

function! s:gobuf(stack, bufnr) abort
   let success = 0
   call bufstack#addvisited(a:stack, bufnr('%'))
   let g:bufstack_switching = 1
   try
      exe 'b' a:bufnr
      call bufstack#add_mru(a:bufnr)
      let success = 1
   finally
      let g:bufstack_switching = 0
   endtry
   return success
endfunction

" Get all buffers not in l.
function! s:get_freebufs(l) abort
   return filter(range(1, bufnr('$')), 'buflisted(v:val) && index(a:l, v:val) < 0')
endfunction

" Get all buffers in mru and not in l.
function! s:get_mrubufs(l) abort
   return filter(copy(g:bufstack_mru), 'buflisted(v:val) && index(a:l, v:val) < 0')
endfunction

" Find the cnt'th buffer to switch to.
"   bufs  - The buffer list.
"   index - The old buffer stack index.
"   cnt   - The count.
" returns [index, cnt]
"   index - The found index
"   cnt   - The remaining count if not enough
"           buffers are in the list
function! s:findnextbuf(bufs, index, cnt) abort
   if a:index < 0
      throw "index < 0"
   endif
   if a:cnt < 0
      let ac = -a:cnt
      let dir = 1
      let start = a:index + 1
      let end = len(a:bufs) - 1
   else
      let ac = a:cnt
      let dir = -1
      let start = a:index - 1
      let end = 0
   endif
   let idx = a:index
   for i in range(start, end, dir)
      if buflisted(a:bufs[i])
         let idx = i
         let ac -= 1
         if ac <= 0
            return [i, 0]
         endif
      endif
   endfor
   return [idx, a:cnt < 0 ? -ac : ac]
endfunction

" Extend the buffer list for switching to the cnt'th buffer.
"   bufs  - The buffer list.
"   index - The old buffer stack index.
"   cnt   - The count.
"   fbufs - List of buffers to extend the buffer list.
" returns [bufs, index, cnt]
"   bufs  - The new buffer list
"   index - The found index
"   cnt   - The remaining count if not enough buffers could be found.
function! s:extendbufs(bufs, idx, cnt, fbufs) abort
   if a:idx < 0
      throw "idx < 0"
   endif
   if empty(a:fbufs)
      return [a:bufs, a:idx, a:cnt]
   endif
   let bufs = a:bufs
   if a:cnt < 0
      " append first -cnt free buffers
      let ac = -a:cnt
      let bufs = extend(a:fbufs[:(ac - 1)], bufs, 0)
      let idx = len(bufs) - 1
   else
      " prepend last cnt free buffers
      let ac = a:cnt
      let first = len(a:fbufs) - ac
      let bufs = extend(a:fbufs[(first < 0 ? 0 : first):], bufs)
      let idx = 0
   endif
   let ac -= len(a:fbufs)
   if ac < 0
      let ac = 0
   endif
   return [bufs, idx, a:cnt < 0 ? -ac : ac]
endfunction

" Find the cnt'th buffer to switch to.
" If cnt moves over an end of the buffer list, it is extended
" as needed from the mru list and all remaining listed buffers.
" returns the same as s:extendbufs()
function! s:findnext_extend(bufs, index, cnt) abort
   let [bufs, idx, c] = [a:bufs, a:index, a:cnt]
   if c != 0 " find in window local list
      let [idx, c] = s:findnextbuf(bufs, idx, c)
   endif
   if c < 0 " mru only when going backwards
      let [bufs, idx, c] = s:extendbufs(a:bufs, idx, c, s:get_mrubufs(a:bufs))
   endif
   if c != 0
      if c < 0
         let fbufs = s:get_freebufs(a:bufs)
      else
         " reverse and ignore mru buffers when going forwards
         let fbufs = reverse(s:get_freebufs(a:bufs + s:get_mrubufs(a:bufs)))
      endif
      let [bufs, idx, c] = s:extendbufs(a:bufs, idx, c, fbufs)
   endif
   return [bufs, idx, c]
endfunction

function! s:forget_win(bufnr) abort
   let stack = bufstack#get_stack()
   if bufnr('%') == a:bufnr
      silent if !bufstack#cmd#alt()
         enew
      endif
      call bufstack#applylast(stack)
   endif
   call filter(stack.bufs, 'v:val != a:bufnr')
endfunction

" Go to every window with the given buffer, change to
" the alternate buffer and remove the buffer from the stack.
function! s:forget(bufnr) abort
   call s:tabwindo(function('s:forget_win'), a:bufnr)
   call filter(g:bufstack_mru, 'v:val != a:bufnr')
endfunction

" Api Functions: {{{1

" Change to the cnt'th next buffer.
" Negative numbers to change to the -cnt'th previous buffer.
function! bufstack#cmd#next(cnt) abort
   let success = 0
   let stack = bufstack#get_stack()
   let [bufs, idx, c] = s:findnext_extend(stack.bufs, stack.index, a:cnt)
   if c != 0 && (!g:bufstack_goend || bufs[idx] == bufnr('%'))
      echohl ErrorMsg
      echo printf('At %s of buffer list', c < 0 ? 'end' : 'start')
      echohl None
   else
      let stack.bufs = bufs
      let stack.index = idx
      let bn = bufs[idx]
      call s:gobuf(stack, bn)
      let success = 1
   endif
   return success
endfunction

" Change to the alternate buffer.
function! bufstack#cmd#alt(...) abort
   let cnt = get(a:000, 0, -1)
   let success = 0
   let stack = bufstack#get_stack()
   call bufstack#applylast(stack)
   if bufstack#cmd#next(cnt)
      call bufstack#applylast(stack)
      let success = 1
   endif
   return success
endfunction

" Send the current buffer to the bottom of the stack.
" Does not affect any other windows.
function! bufstack#cmd#bury(count) abort
   let success = 0
   let stack = bufstack#get_stack()
   let bufnr = bufnr('%')
   if a:count == 0
      return 1
   endif
   if bufstack#cmd#alt(-1)
      " move buffer to the bottom of the stack
      let stack.bufs = filter(stack.bufs, 'v:val != bufnr')
      if a:count < 0 || a:count >= len(stack.bufs)
         call add(stack.bufs, bufnr)
      else
         call insert(stack.bufs, bufnr, a:count)
      endif
      let success = 1
   endif
   return success
endfunction

" Delete the buffer without closing any windows.
" Windows showing the buffer are changed to the alternate
" buffer. If one has no alternate buffer, it is changed to
" an empty buffer.
function! bufstack#cmd#delete(bufnr, ...) abort
   let success = 0
   let delwin = get(a:000, 0, 0)
   call s:forget(a:bufnr)
   silent exe 'bdelete' a:bufnr
   if delwin
      silent! wincmd c
   endif
   return success
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
