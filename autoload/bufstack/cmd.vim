" File:        bufstack.vim
" Author:      ferreum (github.com/ferreum)
" Created:     2014-06-29
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

" Util: {{{1

" @vimlint(EVL103, 1, a:cmd)
function! s:windo(cmd, ...) abort
   let o_win = winnr()
   try
      windo call call(a:cmd, a:000)
   finally
      exe o_win . 'wincmd w'
   endtry
endfunction
" @vimlint(EVL103, 0, a:cmd)

" @vimlint(EVL102, 1, l:args)
function! s:tabwindo(cmd, ...) abort
   let o_tab = tabpagenr()
   let args = extend([a:cmd], a:000)
   try
      tabdo call call('s:windo', args)
   finally
      exe 'tabp' o_tab
   endtry
endfunction
" @vimlint(EVL102, 0, l:args)

" Core: {{{1

function! s:gobuf(bufnr) abort
   let g:bufstack_switching = 1
   try
      exe 'b' a:bufnr
      call bufstack#add_mru(a:bufnr)
   finally
      let g:bufstack_switching = 0
   endtry
endfunction

" Get all buffers not in l.
function! s:get_freebufs(l) abort
   return filter(range(1, bufnr('$')), 'bufstack#util#is_listed(v:val) && index(a:l, v:val) < 0')
endfunction

" Get all buffers in mru and not in l.
function! s:get_mrubufs(l) abort
   return filter(copy(g:bufstack_mru), 'bufstack#util#is_listed(v:val) && index(a:l, v:val) < 0')
endfunction

" Find the count'th buffer to switch to.
"   bufs  - The buffer list.
"   index - The old buffer stack index.
"   count - The count.
" returns [index, count]
"   index - The found index
"   count - The remaining count if not enough
"           buffers are in the list
function! s:findnext(bufs, index, count) abort
   if a:index < 0
      throw "index < 0"
   endif
   if a:count < 0
      let ac = -a:count
      let dir = 1
      let start = a:index + 1
      let end = len(a:bufs) - 1
   else
      let ac = a:count
      let dir = -1
      let start = a:index - 1
      let end = 0
   endif
   let idx = a:index
   for i in range(start, end, dir)
      if bufstack#util#is_listed(a:bufs[i])
         let idx = i
         let ac -= 1
         if ac <= 0
            return [i, 0]
         endif
      endif
   endfor
   return [idx, a:count < 0 ? -ac : ac]
endfunction

" Extend the buffer list for switching to the count'th buffer.
"   bufs  - The buffer list.
"   index - The old buffer stack index.
"   count - The count.
"   fbufs - List of buffers to extend the buffer list.
" returns [bufs, index, count]
"   bufs  - The new buffer list
"   index - The found index
"   count - The remaining count if not enough buffers could be found.
function! s:extendbufs(bufs, idx, count, fbufs) abort
   if a:idx < 0
      throw "idx < 0"
   endif
   if empty(a:fbufs)
      return [a:bufs, a:idx, a:count]
   endif
   let bufs = a:bufs
   if a:count < 0
      " append first -count free buffers
      let ac = -a:count
      let bufs = extend(a:fbufs[:(ac - 1)], bufs, 0)
      let idx = len(bufs) - 1
   else
      " prepend last count free buffers
      let ac = a:count
      let first = len(a:fbufs) - ac
      let bufs = extend(a:fbufs[(first < 0 ? 0 : first):], bufs)
      let idx = 0
   endif
   let ac -= len(a:fbufs)
   if ac < 0
      let ac = 0
   endif
   return [bufs, idx, a:count < 0 ? -ac : ac]
endfunction

" Find the count'th buffer to switch to.
" If count moves over an end of the buffer list, it is extended
" as needed from the mru list and all remaining listed buffers.
" returns the same as s:extendbufs()
function! s:findnext_extend(bufs, index, count) abort
   let [bufs, idx, c] = [a:bufs, a:index, a:count]
   if c != 0 " find in window local list
      let [idx, c] = s:findnext(bufs, idx, c)
   endif
   if c < 0 " mru only when going backwards
      let [bufs, idx, c] = s:extendbufs(a:bufs, idx, c, s:get_mrubufs(a:bufs))
   endif
   if c != 0
      if c < 0
         let fbufs = s:get_freebufs(a:bufs)
      else
         " ignore mru buffers when going forwards and reverse the direction
         let fbufs = reverse(s:get_freebufs(a:bufs + s:get_mrubufs(a:bufs)))
      endif
      let [bufs, idx, c] = s:extendbufs(a:bufs, idx, c, fbufs)
   endif
   return [bufs, idx, c]
endfunction

function! s:forget_win(bufnr) abort
   let stack = bufstack#get_stack()
   if a:bufnr == bufstack#util#get_current_bufnr(stack)
      silent if !bufstack#cmd#alt()
         enew
      endif
   endif
   let index = index(stack.bufs, a:bufnr)
   if index >= 0
      if index < stack.index
         let stack.index -= 1
      endif
      call remove(stack.bufs, index)
   endif
endfunction

function! s:boundserror(bufs, idx, c, startcount) abort
   if a:c != 0 && (!g:bufstack_goend || a:c == a:startcount)
      echohl ErrorMsg
      echo printf('At %s of buffer list', a:c < 0 ? 'end' : 'start')
      echohl None
      return 1
   else
      return 0
   end
endfunction

" Go to every window with the given buffer, change to
" the alternate buffer and remove the buffer from the stack.
function! s:forget(bufnr) abort
   call s:tabwindo(function('s:forget_win'), a:bufnr)
   call filter(g:bufstack_mru, 'v:val != a:bufnr')
endfunction

" Api Functions: {{{1

" Change to the count'th next buffer.
" Negative numbers to change to the -count'th previous buffer.
function! bufstack#cmd#next(count) abort
   let success = 0
   let stack = bufstack#get_stack()
   let [bufs, idx, c] = s:findnext_extend(stack.bufs, stack.index, a:count)
   if !s:boundserror(bufs, idx, c, a:count)
      let oldb = bufstack#util#get_current_bufnr(stack)
      call s:gobuf(bufs[idx])
      let stack.bufs = bufs
      let stack.index = idx
      call bufstack#addvisited(stack, oldb)
      let success = 1
   endif
   return success
endfunction

" Change to the alternate buffer.
function! bufstack#cmd#alt(...) abort
   let success = 0
   let cnt = get(a:000, 0, -1)
   let stack = bufstack#get_stack()
   let tmps = deepcopy(stack)
   call bufstack#applylast(tmps)
   let [idx, c] = s:findnext(tmps.bufs, tmps.index, cnt)
   if !s:boundserror(tmps.bufs, idx, c, cnt)
      let newbuf = tmps.bufs[idx]
      let newidx = index(stack.bufs, newbuf)
      let oldb = bufstack#util#get_current_bufnr(stack)
      call s:gobuf(newbuf)
      let stack.index = newidx
      call filter(stack.last, 'v:val != newbuf')
      call bufstack#addvisited(stack, oldb)
      let success = 1
   endif
   return success
endfunction

" Remove the current buffer from the stack.
" With count > 1, moves the buffer count positions down.
" Switches to the previous buffer.
" Does not affect any other windows.
function! bufstack#cmd#bury(count) abort
   if a:count == 0
      return 1
   endif
   let success = 0
   if bufstack#cmd#alt(-1)
      let stack = bufstack#get_stack()
      let bufnr = stack.last[0]
      let index = index(stack.bufs, bufnr)
      call remove(stack.bufs, index)
      call remove(stack.last, 0)
      if a:count > 0
         call add(stack.last, bufnr)
         let newpos = index + a:count
         if newpos >= len(stack.bufs)
            call add(stack.bufs, bufnr)
         else
            call insert(stack.bufs, bufnr, a:count)
         endif
      endif
      if index < stack.index && (a:count <= 0 || newpos >= stack.index)
         let stack.index -= 1
      endif
      let success = 1
   endif
   return success
endfunction

" Remove all but count last used buffers from the stack.
" Does not affect any other windows.
function! bufstack#cmd#only(count) abort
   let cnt = a:count < 1 ? 1 : a:count
   let stack = bufstack#get_stack()
   call bufstack#applylast(stack)
   let bufs = stack.bufs
   if len(bufs) > cnt
      call remove(bufs, cnt, len(bufs) - 1)
      let stack.tick += 1
   endif
   return 1
endfunction

" Delete the buffer without closing any windows.
" Windows showing the buffer are changed to the alternate
" buffer. If one has no alternate buffer, it is changed to
" an empty buffer.
function! bufstack#cmd#delete(bufnr, ...) abort
   let success = 0
   let stack = bufstack#get_stack()
   let mybuf = bufstack#util#get_current_bufnr(stack)
   let bufnr = a:bufnr < 0 ? mybuf : a:bufnr
   call s:forget(bufnr)
   if bufloaded(bufnr) " incase the buffer was deleted by leaving it
      silent exe 'bdelete' bufnr
   endif
   if mybuf == bufnr && get(a:000, 0, 0)
      silent! wincmd c
   endif
   return success
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
