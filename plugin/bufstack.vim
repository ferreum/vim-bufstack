" File:        bufstack.vim
" Description: bufstack
" Created:     2014-06-20
" Last Change: 2014-06-27

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:bufstack_max')
   let g:bufstack_max = 42
endif
if !exists('g:bufstack_max_mru')
   let g:bufstack_max_mru = g:bufstack_max * 2
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

function! s:buflist_insert(list, item, max) abort
   call insert(filter(a:list, 'v:val != a:item'), a:item)
   if len(a:list) > a:max
      call remove(a:list, a:max, len(a:list) - 1)
   endif
   return a:list
endfunction

if !exists('g:bufstack_mru')
   let g:bufstack_mru = []
endif

function! s:add_mru(bufnr) abort
   call s:buflist_insert(g:bufstack_mru, a:bufnr, g:bufstack_max_mru)
endfunction

function! s:addvisited(stack, bufnr) abort
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

function! s:initstack() abort
   let altwin = winnr('#')
   let w:bufstack = altwin >= 1 ? deepcopy(getwinvar(altwin, 'bufstack', {})) : {}
   if empty(w:bufstack)
      let w:bufstack.bufs = []
      let w:bufstack.last = []
      let w:bufstack.index = 0
   endif
   call s:applylast(w:bufstack)
   let w:bufstack.bufs = filter(copy(g:bufstack_mru), 'buflisted(v:val)')
endfunction

function! s:get_stack() abort
   if !exists('w:bufstack')
      if buflisted(bufnr('%'))
         call s:add_mru(bufnr('%'))
      endif
      call s:initstack()
   endif
   return w:bufstack
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
   let stack = s:get_stack()
   if bufnr('%') == a:bufnr
      silent if !bufstack#alt()
         enew
      endif
      call s:applylast(stack)
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
      call s:gobuf(stack, bn)
      let success = 1
   endif
   return success
endfunction

" Change to the alternate buffer.
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

" Send the current buffer to the bottom of the stack.
" Does not affect any other windows.
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

" Delete the buffer without closing any windows.
" Windows showing the buffer are changed to the alternate
" buffer. If one has no alternate buffer, it is changed to
" an empty buffer.
function! bufstack#delete(bufnr, ...) abort
   let success = 0
   let delwin = get(a:000, 0, 0)
   call s:forget(a:bufnr)
   silent exe 'bdelete' a:bufnr
   if delwin
      silent! wincmd c
   endif
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
      call s:add_mru(a:bufnr)
   endif
endfunction

augroup plugin_bufstack
   autocmd!
   autocmd BufEnter * call s:bufenter()
   autocmd WinEnter * call s:checkinit()
   autocmd BufNew * call s:bufnew(expand("<abuf>"))
augroup END

" function! s:addbufs() abort
"    for b in range(bufnr('$'), 0, -1)
"       call s:bufnew(b)
"    endfor
" endfunction
" call s:addbufs()

" Mappings: {{{1

nnoremap <Plug>(bufstack-previous) :<C-u>call bufstack#next(-v:count1)<CR>
nnoremap <Plug>(bufstack-next) :<C-u>call bufstack#next(v:count1)<CR>
nnoremap <Plug>(bufstack-delete) :<C-u>call bufstack#delete(bufnr('%'))<CR>
nnoremap <Plug>(bufstack-delete-win) :<C-u>call bufstack#delete(bufnr('%'), 1)<CR>
nnoremap <Plug>(bufstack-bury) :<C-u>call bufstack#bury()<CR>
nnoremap <Plug>(bufstack-alt) :<C-u>call bufstack#alt(-v:count1)<CR>

" Test Mappings: {{{1

if get(g:, 'bufstack_mappings', 1)
   nmap ^p <Plug>(bufstack-previous)
   nmap ^n <Plug>(bufstack-next)
   nmap ^b <Plug>(bufstack-bury)
   nmap ^d <Plug>(bufstack-delete)
   nmap ^D <Plug>(bufstack-delete-win)
   nmap ^^ <Plug>(bufstack-alt)
   nmap <C-^> <Plug>(bufstack-alt)
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
