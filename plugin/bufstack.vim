" File:        bufstack.vim
" Author:      ferreum (github.com/ferreum)
" Created:     2014-06-20
" Last Change: 2016-10-14
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

" Options: {{{1

if !exists('g:bufstack_max')
   let g:bufstack_max = 42
endif
if !exists('g:bufstack_max_mru')
   let g:bufstack_max_mru = g:bufstack_max * 2
endif
if !exists('g:bufstack_goend')
   let g:bufstack_goend = 1
endif

" Variables: {{{1

if !exists('g:bufstack_switching')
   let g:bufstack_switching = 0
endif
if !exists('g:bufstack_mru')
   let g:bufstack_mru = []
endif

" Setup: {{{1

function! s:bufenter() abort
   if !g:bufstack_switching
      let bn = bufnr('%')
      let stack = bufstack#get_stack()
      call bufstack#add_mru(bn)
      call bufstack#update_current(stack, bn)
   endif
endfunction

function! s:bufnew(bufnr) abort
   if buflisted(a:bufnr) && index(g:bufstack_mru, a:bufnr) < 0
      call bufstack#add_mru(a:bufnr)
   endif
endfunction

augroup plugin_bufstack
   autocmd!
   autocmd BufEnter * call s:bufenter()
   autocmd WinEnter * call bufstack#get_stack() " init window
   autocmd BufNew * call s:bufnew(expand("<abuf>"))
augroup END

" Commands: {{{1

command! -count=1 BsPrevious call bufstack#cmd#next(-<count>)
command! -count=1 BsNext call bufstack#cmd#next(<count>)
command! -count=1 BsBury call bufstack#cmd#bury(<count>)
command! -count=1 -bang BsDelete call bufstack#cmd#delete(bufnr('%'), <q-bang> == '!')
command! -count=1 BsAlternate call bufstack#cmd#alt(-<count>)

" Mappings: {{{1

nnoremap <silent> <Plug>(bufstack-previous) :<C-u>call bufstack#cmd#next(-v:count1)<CR>
nnoremap <silent> <Plug>(bufstack-next) :<C-u>call bufstack#cmd#next(v:count1)<CR>
nnoremap <silent> <Plug>(bufstack-delete) :<C-u>call bufstack#cmd#delete(bufnr('%'))<CR>
nnoremap <silent> <Plug>(bufstack-delete-win) :<C-u>call bufstack#cmd#delete(bufnr('%'), 1)<CR>
nnoremap <silent> <Plug>(bufstack-bury) :<C-u>call bufstack#cmd#bury(v:count ? v:count : -1)<CR>
nnoremap <silent> <Plug>(bufstack-alt) :<C-u>call bufstack#cmd#alt(-v:count1)<CR>
nnoremap <silent> <Plug>(bufstack-only) :<C-u>call bufstack#cmd#only(v:count1)<CR>

" Test Mappings: {{{1

if get(g:, 'bufstack_mappings', 0)
   nmap ^p <Plug>(bufstack-previous)
   nmap ^n <Plug>(bufstack-next)
   nmap ^b <Plug>(bufstack-bury)
   nmap ^d <Plug>(bufstack-delete)
   nmap ^D <Plug>(bufstack-delete-win)
   nmap ^^ <Plug>(bufstack-alt)
   nmap ^o <Plug>(bufstack-only)
   nmap <C-^> <Plug>(bufstack-alt)
endif

if get(g:, 'bufstack_leadermappings', 1)
   nmap <Leader>bb <Plug>(bufstack-alt)
   nmap <Leader>bp <Plug>(bufstack-previous)
   nmap <Leader>bn <Plug>(bufstack-next)
   nmap <Leader>bg <Plug>(bufstack-bury)
   nmap <Leader>bd <Plug>(bufstack-delete)
   nmap <Leader>bD <Plug>(bufstack-delete-win)
   nmap <Leader>b^ <Plug>(bufstack-alt)
   nmap <Leader>ba <Plug>(bufstack-alt)
   nmap <Leader>bo <Plug>(bufstack-only)
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=3 ts=3 sts=0 et sta sr ft=vim fdm=marker:
