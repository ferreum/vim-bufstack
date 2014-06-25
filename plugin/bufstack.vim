" File:        bufstack.vim
" Description: bufstack
" Created:     2014-06-20
" Last Change: 2014-06-25

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:bufstack_max')
   let g:bufstack_max = 42
endif
if !exists('g:bufstack_goend')
   let g:bufstack_goend = 1
endif

let s:switching = 0

" Util: {{{1

function! s:echoerr(err) abort
   echohl ErrorMsg
   echo a:err
   echohl None
endfunction

" Core: {{{1

function! s:buflist_insert(list, item) abort
   call insert(filter(a:list, 'v:val != a:item'), a:item)
   if len(a:list) > g:bufstack_max
      call remove(g:bufstack_mru, 0, g:bufstack_max - 1)
   endif
   return a:list
endfunction

if !exists('g:bufstack_mru')
   let g:bufstack_mru = []
endif

function! s:add_mru(bufnr) abort
   call s:buflist_insert(g:bufstack_mru, a:bufnr)
endfunction

function! s:initstack() abort
   let altwin = winnr('#')
   let w:bufstack = altwin >= 1 ? deepcopy(getwinvar(altwin, 'bufstack', {})) : {}
   if empty(w:bufstack)
      let w:bufstack.last = []
      let w:bufstack.index = 0
   endif
   let w:bufstack.bufs = filter(copy(g:bufstack_mru), 'buflisted(v:val)')
endfunction

function! s:get_stack() abort
   if !exists('w:bufstack')
      call s:add_mru(bufnr('%'))
      call s:initstack()
   endif
   return w:bufstack
endfunction

function! s:addvisited(stack, bufnr) abort
   call s:buflist_insert(a:stack.last, a:bufnr)
endfunction

function! s:applylast_(stack) abort
   " move visited buffers to top of the stack
   let bufs = a:stack.bufs
   let last = a:stack.last
   call filter(bufs, 'index(last, v:val) < 0')
   let bufs = extend(last, bufs)
   if len(bufs) > g:bufstack_max
      call remove(bufs, 0, g:bufstack_max - 1)
   endif
   let a:stack.bufs = bufs
   let a:stack.last = []
endfunction

function! s:applyindex_(stack) abort
   if !empty(a:stack.last)
      call s:addvisited(a:stack, a:stack.bufs[a:stack.index])
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
   let success = 0
   call s:addvisited(a:stack, bufnr('%'))
   let s:switching = 1
   try
      exe 'b' a:bufnr
      call s:add_mru(a:bufnr)
      let success = 1
   finally
      let s:switching = 0
   endtry
   return success
endfunction

function! s:get_freebufs(l) abort
   return filter(range(bufnr('$'), 1, -1), 'buflisted(v:val) && index(a:l, v:val) < 0')
endfunction

function! s:get_mrubufs(l) abort
   return filter(copy(g:bufstack_mru), 'buflisted(v:val) && index(a:l, v:val) < 0')
endfunction

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
      let bufs = bufs + a:fbufs[:(ac - 1)]
      let idx = len(bufs) - 1
   else
      " prepend last cnt free buffers
      let ac = a:cnt
      let first = len(a:fbufs) - ac
      if first < 0
         let first = 0
      endif
      let bufs = extend(a:fbufs[(first):], bufs)
      let idx = 0
   endif
   let ac -= len(a:fbufs)
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
      let [bufs, idx, c] = s:extendbufs(a:bufs, idx, c, s:get_mrubufs(a:bufs))
      if c == 0
         return [bufs, idx, 0]
      else
         return s:extendbufs(a:bufs, idx, c, s:get_freebufs(a:bufs))
      endif
   endif
endfunction

function! s:hidebuf_win(bufnr) abort
   if bufnr('%') == a:bufnr
      if !bufstack#alt()
         enew
      endif
      let stack = s:get_stack()
      call s:applylast(stack)
      call filter(stack.bufs, 'v:val != a:bufnr')
   endif
endfunction

function! s:hidebuf_tab(bufnr) abort
   let o_win = winnr()
   try
      windo call s:hidebuf_win(a:bufnr)
   finally
      exe o_win . 'wincmd w'
   endtry
endfunction

function! s:hidebuf(bufnr) abort
   let o_tab = tabpagenr()
   try
      silent tabdo call s:hidebuf_tab(a:bufnr)
      call filter(g:bufstack_mru, 'v:val != a:bufnr')
   finally
      exe 'tabp' o_tab
   endtry
endfunction

" Api Functions: {{{1

function! bufstack#next(cnt) abort
   let success = 0
   let stack = s:get_stack()
   let [bufs, idx, c] = s:findnext_extend(stack.bufs, stack.index, a:cnt)
   if c != 0 && (!g:bufstack_goend || bufs[idx] == bufnr('%'))
      call s:echoerr(printf('At %s of buffer list', c < 0 ? 'end' : 'start'))
   else
      let stack.bufs = bufs
      let stack.index = idx
      let bn = bufs[idx]
      call s:add_mru(bn)
      call s:gobuf(stack, bn)
      let success = 1
   endif
   return success
endfunction

function! bufstack#alt(...) abort
   let cnt = get(a:000, 0, -1)
   let success = 0
   let stack = s:get_stack()
   call s:applylast(stack)
   if bufstack#next(cnt)
      call s:applylast(stack)
      let success = 1
   endif
   return success
endfunction

function! bufstack#bury() abort
   let success = 0
   let stack = s:get_stack()
   let bufnr = bufnr('%')
   if bufstack#alt(-1)
      " move buffer to the bottom of the stack
      let stack.bufs = filter(stack.bufs, 'v:val != bufnr')
      call add(stack.bufs, bufnr)
      let success = 1
   endif
   return success
endfunction

function! bufstack#delete(bufnr) abort
   let success = 0
   call s:hidebuf(a:bufnr)
   exe 'bd' a:bufnr
   return success
endfunction

" Setup: {{{1

function! s:bufenter() abort
   if !s:switching
      call s:add_mru(bufnr('%'))
      call s:maketop(s:get_stack(), bufnr('%'))
   endif
endfunction

function! s:checkinit() abort
   call s:get_stack()
endfunction

function! s:bufnew(bufnr) abort
   if buflisted(a:bufnr) && index(g:bufstack_mru, a:bufnr) < 0
      call insert(g:bufstack_mru, a:bufnr)
   endif
endfunction

augroup plugin_bufstack
   autocmd!
   autocmd BufEnter * call s:bufenter()
   autocmd WinEnter * call s:checkinit()
   autocmd BufNew * call s:bufnew(expand("<abuf>"))
augroup END

function! s:addbufs() abort
   for b in range(bufnr('$'), 0, -1)
      call s:bufnew(b)
   endfor
endfunction

call s:addbufs()

" Mappings: {{{1

nnoremap <Plug>(bufstack-previous) :<C-u>call bufstack#next(-v:count1)<CR>
nnoremap <Plug>(bufstack-next) :<C-u>call bufstack#next(v:count1)<CR>
nnoremap <Plug>(bufstack-delete) :<C-u>call bufstack#delete(bufnr('%'))<CR>
nnoremap <Plug>(bufstack-bury) :<C-u>call bufstack#bury()<CR>
nnoremap <Plug>(bufstack-alt) :<C-u>call bufstack#alt(-v:count1)<CR>

" Test Mappings: {{{1

if get(g:, 'bufstack_mappings', 1)
   nmap ^p <Plug>(bufstack-previous)
   nmap ^n <Plug>(bufstack-next)
   nmap ^b <Plug>(bufstack-bury)
   nmap ^d <Plug>(bufstack-delete)
   nmap ^^ <Plug>(bufstack-alt)
   nmap <C-^> <Plug>(bufstack-alt)
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
