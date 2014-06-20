" File:        bufstack.vim
" Description: bufstack
" Created:     2014-06-20
" Last Change: 2014-06-20

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
      let w:bufstack.index = 0
   endif
endfunction

function! s:get_stack() abort
   if !exists('w:bufstack')
      call s:initstack()
   endif
   return w:bufstack
endfunction

function! s:applyindex(stack) abort
   if a:stack.index > 0
      let idx = a:stack.index
      let a:stack.index = 0
      call s:maketop(a:stack.stack[idx])
   endif
endfunction

function! s:maketop(bufnr) abort
   let stack = s:get_stack()

   call s:applyindex(stack)

   let l = filter(stack.stack, 'v:val != a:bufnr')
   if len(l) > g:bufstack_max
      let l = l[(1-g:bufstack_max):]
   endif
   let stack.stack = insert(l, a:bufnr)
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

function! s:findbufs(stack) abort
   let l = a:stack.stack
   let bufs = filter(range(1, bufnr('$')), 'buflisted(v:val) && index(l, v:val) < 0')
   return bufs
endfunction

function! s:findnextbuf(stack, cnt) abort
   let c = a:cnt
   let i = 0
   for bn in a:stack.stack[1:]
      let i += 1
      if buflisted(bn)
         let c -= 1
         if c <= 0
            return [i, 0]
         endif
      endif
   endfor
   return [-1, c]
endfunction

function! s:gofindnext(stack, count) abort
   " echom "gofindnext: c=" . a:count
   if a:count == 0
      call s:echoerr("count == 0")
      return 0
   endif
   let bufs = s:findbufs(a:stack)
   let ac = a:count < 0 ? -a:count : a:count
   if len(bufs) < ac
      call s:echoerr("No buffer found")
   else
      if a:count < 0
         let abufs = bufs[(-ac):]
         let a:stack.stack = extend(a:stack.stack, abufs)
         let bn = a:stack.stack[-1]
      else
         let abufs = reverse(bufs[:(ac - 1)])
         let a:stack.stack = extend(abufs, a:stack.stack)
         let bn = a:stack.stack[0]
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
   let stack = s:get_stack()
   let ac = a:cnt < 0 ? -a:cnt : a:cnt
   " echom "a:cnt=" . a:cnt . " ac=" . ac
   if a:cnt > 0
      if stack.index == 0
         let bufs = []
      elseif stack.index < 0
         throw "stack.index < 0"
      else
         let bufs = reverse(stack.stack[:(stack.index-1)])
      endif
   elseif stack.index >= len(stack.stack)
      throw "stack.index >= len(stack)"
   else
      let bufs = stack.stack[(stack.index+1):]
   endif
   " echom "bufs=" . string(bufs)
   let [i, ac] = s:findnextbuf(bufs, ac)
   " echom "a:cnt=" . a:cnt . " i=" . i . " ac=" . ac
   if ac > 0
      call s:gofindnext(stack, a:cnt < 0 ? -ac : ac)
   else
      let idx = stack.index - (a:cnt < 0 ? -i : i)
      if idx < 0 || idx >= len(stack.stack)
         call s:echoerr("idx= " . idx . " len=" . len(stack.stack))
      else
         let stack.index = idx
         call s:gobuf(stack.stack[stack.index])
      endif
   endif
endfunction

function! bufstack#bury(bufnr) abort
   let stack = s:get_stack()
   if len(stack.stack) <= 1
      call s:echoerr("Only one buffer in stack")
   else
      call s:applyindex(stack)
      call bufstack#next(-1)
      let stack.index = 0
      let stack.stack = filter(stack.stack, 'v:val != a:bufnr')
      let stack.stack = add(stack.stack, a:bufnr)
   endif
endfunction

function! bufstack#alt() abort
   let stack = s:get_stack()
   if len(stack.stack) <= 1
      call s:echoerr("Only one buffer in stack")
   else
      call s:applyindex(stack)
      let [idx, c] = s:findnextbuf(stack.stack[1:], -1)
      if idx == -1
         call s:echoerr("No buffer found")
      else
         call s:gobuf(stack.stack[idx])
         let stack.index = idx
         call s:applyindex(stack)
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
