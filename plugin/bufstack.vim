" File:        bufstack.vim
" Description: bufstack
" Created:     2014-06-20
" Last Change: 2014-06-23

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:bufstack_max')
   let g:bufstack_max = 40
endif

let s:switching = 0

" Util: {{{1

function! s:echoerr(err) abort
   echohl ErrorMsg
   echo a:err
   echohl None
endfunction

" Core: {{{1

function! s:initstack() abort
   let altwin = winnr('#')
   let w:bufstack = altwin >= 1 ? deepcopy(getwinvar(altwin, 'bufstack', {})) : {}
   if empty(w:bufstack)
      let w:bufstack.stack = []
      let w:bufstack.last = []
      let w:bufstack.index = 0
   endif
endfunction

function! s:get_stack() abort
   if !exists('w:bufstack')
      call s:initstack()
   endif
   return w:bufstack
endfunction

function! s:addvisited(stack, bufnr) abort
   call insert(filter(a:stack.last, 'v:val != a:bufnr'), a:bufnr)
endfunction

function! s:applylast_(stack) abort
   " move visited buffers to top of the stack
   let bufs = a:stack.stack
   let last = a:stack.last
   call filter(bufs, 'index(last, v:val) < 0')
   let bufs = extend(last, bufs)
   if len(bufs) > g:bufstack_max
      let bufs = bufs[:(g:bufstack_max - 1)]
   endif
   let a:stack.stack = bufs
   let a:stack.last = []
endfunction

function! s:applyindex_(stack) abort
   if !empty(a:stack.last)
      call s:addvisited(a:stack, a:stack.stack[a:stack.index])
      let a:stack.index = 0
   endif
endfunction

function! s:applylast(stack) abort
   call s:applyindex_(a:stack)
   call s:applylast_(a:stack)
endfunction

function! s:maketop(stack, bufnr) abort
   call s:applyindex_(a:stack)
   call s:addvisited(a:stack, a:bufnr)
   call s:applylast_(a:stack)
endfunction

function! s:gobuf(stack, bufnr) abort
   " echom "gobuf: nr=" . a:bufnr
   let success = 0
   call s:addvisited(a:stack, bufnr('%'))
   let s:switching = 1
   try
      exe 'b' a:bufnr
      let success = 1
   finally
      let s:switching = 0
   endtry
   return success
endfunction

function! s:getfreebufs(l) abort
   return filter(range(bufnr('$'), 1, -1), 'buflisted(v:val) && index(a:l, v:val) < 0')
endfunction

function! s:findnextbuf(bufs, index, cnt) abort
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
   for i in range(start, end, dir)
      if buflisted(a:bufs[i])
         let ac -= 1
         if ac <= 0
            return [i, 0]
         endif
      endif
   endfor
   return [-1, a:cnt < 0 ? -ac : ac]
endfunction

function! s:extendbufs(bufs, cnt) abort
   let bufs = a:bufs
   let freebufs = s:getfreebufs(bufs)
   if a:cnt < 0
      " append first -cnt free buffers
      let ac = -a:cnt
      let bufs = bufs + freebufs[:(ac - 1)]
      let idx = len(bufs) - 1
   else
      " prepend last cnt free buffers
      let ac = a:cnt
      let bufs = extend(freebufs[(-ac):], bufs)
      let idx = 0
   endif
   let ac -= len(freebufs)
   if ac < 0
      let ac = 0
   endif
   return [bufs, idx, a:cnt < 0 ? -ac : ac]
endfunction

function! s:findnext_extend(bufs, index, cnt) abort
   let [idx, c] = s:findnextbuf(a:bufs, a:index, a:cnt)
   if c == 0
      return [a:bufs, idx, 0]
   else
      return s:extendbufs(a:bufs, c)
   endif
endfunction

" Api Functions: {{{1

function! bufstack#next(cnt) abort
   let success = 0
   let stack = s:get_stack()
   let [bufs, idx, c] = s:findnext_extend(stack.stack, stack.index, a:cnt)
   if c != 0
      call s:echoerr("No buffer found")
   else
      let stack.stack = bufs
      let stack.index = idx
      call s:gobuf(stack, bufs[idx])
      let success = 1
   endif
   return success
endfunction

function! bufstack#bury(bufnr) abort
   let success = 0
   let stack = s:get_stack()
   call s:applylast(stack)
   if bufstack#next(-1)
      call s:applylast(stack)
      " move buffer to the bottom of the stack
      let stack.stack = filter(stack.stack, 'v:val != a:bufnr')
      call add(stack.stack, a:bufnr)
      let success = 1
   endif
   return success
endfunction

function! bufstack#alt() abort
   let success = 0
   let stack = s:get_stack()
   call s:applylast(stack)
   if bufstack#next(-1)
      call s:applylast(stack)
      let success = 1
   endif
   return success
endfunction

" Setup: {{{1

function! s:auenter() abort
   if !s:switching
      call s:maketop(s:get_stack(), bufnr('%'))
   endif
endfunction

function! s:checkinit() abort
   call s:get_stack()
endfunction

augroup plugin_bufstack
   autocmd!
   autocmd BufEnter * call s:auenter()
   autocmd WinEnter * call s:checkinit()
augroup END

" Test Mappings: {{{1

nnoremap ^p :<C-u>call bufstack#next(-v:count1)<CR>
nnoremap ^n :<C-u>call bufstack#next(v:count1)<CR>
nnoremap ^b :<C-u>call bufstack#bury(bufnr('%'))<CR>
nnoremap ^^ :<C-u>call bufstack#alt()<CR>

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
