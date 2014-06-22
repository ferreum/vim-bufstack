" File:        bufstack.vim
" Description: bufstack
" Created:     2014-06-20
" Last Change: 2014-06-22

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

function! s:applyindex(stack) abort
   if !empty(a:stack.last)
      " move visited buffers to top of the stack
      let bufs = a:stack.stack
      let last = a:stack.last
      call s:addvisited(a:stack, bufs[a:stack.index])
      call filter(bufs, 'index(last, v:val) < 0')
      let a:stack.stack = extend(last, bufs)
      let a:stack.last = []
      let a:stack.index = 0
   endif
endfunction

function! s:maketop(stack, bufnr) abort
   call s:applyindex(a:stack)

   let l = filter(a:stack.stack, 'v:val != a:bufnr')
   if len(l) > g:bufstack_max
      let l = l[:(g:bufstack_max)]
   endif
   let a:stack.stack = insert(l, a:bufnr)
endfunction

function! s:addvisited(stack, bufnr) abort
   call insert(filter(a:stack.last, 'v:val != a:bufnr'), a:bufnr)
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

function! s:findbufs(l) abort
   let bufs = filter(range(1, bufnr('$')), 'buflisted(v:val) && index(a:l, v:val) < 0')
   return bufs
endfunction

function! s:findnextbuf(bufs, cnt) abort
   let c = a:cnt
   let i = 0
   for bn in a:bufs
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

function! s:extendbufs(bufs, count) abort
   let bn = -1
   let bufs = a:bufs
   let freebufs = s:findbufs(bufs)
   let ac = a:count < 0 ? -a:count : a:count
   if len(freebufs) < ac
      call s:echoerr("No buffer found")
   else
      if a:count < 0
         let abufs = freebufs[(-ac):]
         let bufs = extend(copy(bufs), abufs)
         let bn = bufs[-1]
      else
         let abufs = reverse(freebufs[:(ac - 1)])
         let bufs = extend(abufs, bufs)
         let bn = bufs[0]
      endif
      let success = 1
   endif
   return [bufs, bn]
endfunction

function! s:gofindnext(stack, count) abort
   " echom "gofindnext: c=" . a:count
   if a:count == 0
      throw "count == 0"
   endif
   let success = 0
   let [bufs, bn] = s:extendbufs(a:stack.stack, a:count)
   if bn != -1
      let a:stack.stack = bufs
      let a:stack.index = a:count < 0 ? len(bufs) - 1 : 0
      call s:gobuf(a:stack, bn)
      let success = 1
   endif
   return success
endfunction

function! s:auenter() abort
   if !s:switching
      call s:maketop(s:get_stack(), bufnr('%'))
   endif
endfunction

" Api Functions: {{{1

function! bufstack#next(cnt) abort
   let success = 0
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
      let success = s:gofindnext(stack, a:cnt < 0 ? -ac : ac)
   else
      let idx = stack.index - (a:cnt < 0 ? -i : i)
      if idx < 0 || idx >= len(stack.stack)
         throw "idx= " . idx . " len=" . len(stack.stack)
      else
         let bn = stack.stack[idx]
         let stack.index = idx
         call s:gobuf(stack, bn)
         let success = 1
      endif
   endif
   return success
endfunction

function! bufstack#bury(bufnr) abort
   let success = 0
   let stack = s:get_stack()
   if len(stack.stack) <= 1
      call s:echoerr("Only one buffer in stack")
   else
      call s:applyindex(stack)
      if bufstack#next(-1)
         call s:applyindex(stack)
         " move buffer to the bottom of the stack
         let stack.stack = filter(stack.stack, 'v:val != a:bufnr')
         let stack.stack = add(stack.stack, a:bufnr)
         let success = 1
      endif
   endif
   return success
endfunction

function! bufstack#alt() abort
   let success = 0
   let stack = s:get_stack()
   call s:applyindex(stack)
   call bufstack#next(-1)
   call s:applyindex(stack)
   return success
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
