" File:        bufstack.vim
" Description: bufstack
" Created:     2014-06-20
" Last Change: 2014-06-20

let s:save_cpo = &cpo
set cpo&vim

let g:bufstack_max = 40

let s:switching = 0

" Util: {{{1

function! s:echoerr(err) abort
   echohl ErrorMsg
   echo a:err
   echohl None
endfunction

" Core: {{{1

function! s:copystack(winnr) abort
   let w:bufstack_stack = a:winnr >= 1 ? copy(getwinvar(a:winnr, 'bufstack_stack', [])) : []
   let w:bufstack_index = a:winnr >= 1 ? getwinvar(a:winnr, 'bufstack_index', 0) : 0
endfunction

function! s:applyindex() abort
   if w:bufstack_index > 0
      let idx = w:bufstack_index
      let w:bufstack_index = 0
      call s:maketop(w:bufstack_stack[idx])
   endif
endfunction

function! s:maketop(bufnr) abort
   if !exists('w:bufstack_stack')
      call s:copystack(winnr('#'))
   endif
   if !exists('w:bufstack_index')
      let w:bufstack_index = 0
   endif

   call s:applyindex()

   let l = filter(w:bufstack_stack, 'v:val != a:bufnr')
   if len(l) > g:bufstack_max
      let l = l[(1-g:bufstack_max):]
   endif
   let w:bufstack_stack = insert(l, a:bufnr)
endfunction

function! s:gobuf(bufnr) abort
   " echom "gobuf: nr=" . a:bufnr
   let s:switching = 1
   try
      exe 'b' a:bufnr
   finally
      let s:switching = 0
   endtry
endfunction

function! s:findbufs() abort
   let l = w:bufstack_stack
   let bufs = filter(range(1, bufnr('$')), 'buflisted(v:val) && index(l, v:val) < 0')
   return bufs
endfunction

function! s:findnextbuf() abort
   let i = 0
   let found = -1
   for bn in w:bufstack_stack[1:]
      let i += 1
      if buflisted(bn)
         return i
      endif
   endfor
   return -1
endfunction

function! s:gofindnext(count) abort
   " echom "gofindnext: c=" . a:count
   if a:count == 0
      call s:echoerr("count == 0")
      return 0
   endif
   let bufs = s:findbufs()
   let ac = a:count < 0 ? -a:count : a:count
   if len(bufs) < ac
      call s:echoerr("No buffer found")
   else
      if a:count < 0
         let abufs = bufs[(-ac):]
         let w:bufstack_stack = extend(w:bufstack_stack, abufs)
         let bn = w:bufstack_stack[-1]
      else
         let abufs = reverse(bufs[:(ac - 1)])
         let w:bufstack_stack = extend(abufs, w:bufstack_stack)
         let bn = w:bufstack_stack[0]
      endif
      call s:gobuf(bn)
      return 1
   endif
endfunction

function! s:auenter() abort
   if !s:switching
      call s:maketop(bufnr('%'))
   endif
endfunction

" Api Functions: {{{1

function! bufstack#next(cnt) abort
   let ac = a:cnt < 0 ? -a:cnt : a:cnt
   " echom "a:cnt=" . a:cnt . " ac=" . ac
   if a:cnt > 0
      if w:bufstack_index == 0
         let bufs = []
      else
         let bufs = reverse(w:bufstack_stack[:(w:bufstack_index-1)])
      endif
   else
      let bufs = w:bufstack_stack[(w:bufstack_index+1):]
   endif
   " echom "bufs=" . string(bufs)
   let c = 0
   for bn in bufs
      let c += 1
      if buflisted(bn)
         let ac -= 1
         if ac <= 0
            break
         endif
      endif
   endfor
   " echom "a:cnt=" . a:cnt . " c=" . c . " ac=" . ac
   if ac > 0
      call s:gofindnext(a:cnt < 0 ? -ac : ac)
   else
      let idx = w:bufstack_index - (a:cnt < 0 ? -c : c)
      if idx < 0 || idx >= len(w:bufstack_stack)
         call s:echoerr("idx = " . idx . " len=" . len(w:bufstack_stack))
      else
         let w:bufstack_index = idx
         call s:gobuf(w:bufstack_stack[w:bufstack_index])
      endif
   endif
endfunction

function! bufstack#bury(bufnr) abort
   if len(w:bufstack_stack) <= 1
      call s:echoerr("Only one buffer in stack")
   else
      call s:applyindex()
      call bufstack#next(-1)
      let w:bufstack_index = 0
      let w:bufstack_stack = filter(w:bufstack_stack, 'v:val != a:bufnr')
      let w:bufstack_stack = add(w:bufstack_stack, a:bufnr)
   endif
endfunction

function! bufstack#alt() abort
   if len(w:bufstack_stack) <= 1
      call s:echoerr("Only one buffer in stack")
   else
      call s:applyindex()
      let idx = s:findnextbuf()
      if idx == -1
         call s:echoerr("No buffer found")
      else
         call s:gobuf(w:bufstack_stack[idx])
         let w:bufstack_index = idx
         call s:applyindex()
      endif
   endif
endfunction

" Setup: {{{1

augroup plugin_bufstack
   autocmd!
   autocmd BufEnter * call s:auenter()
augroup END

" Test Mappings: {{{1

nnoremap ^p :<C-u>call bufstack#next(-v:count1)<CR>
nnoremap ^n :<C-u>call bufstack#next(v:count1)<CR>
nnoremap ^b :<C-u>call bufstack#bury(bufnr('%'))<CR>
nnoremap ^^ :<C-u>call bufstack#alt()<CR>

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
