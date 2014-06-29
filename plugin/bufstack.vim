" File:        bufstack.vim
" Author:      ferreum (github.com/ferreum)
" Created:     2014-06-20
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
      call bufstack#add_mru(bufnr('%'))
      call bufstack#maketop(bufstack#get_stack(), bufnr('%'))
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

" Mappings: {{{1

nnoremap <Plug>(bufstack-previous) :<C-u>call bufstack#cmd#next(-v:count1)<CR>
nnoremap <Plug>(bufstack-next) :<C-u>call bufstack#cmd#next(v:count1)<CR>
nnoremap <Plug>(bufstack-delete) :<C-u>call bufstack#cmd#delete(bufnr('%'))<CR>
nnoremap <Plug>(bufstack-delete-win) :<C-u>call bufstack#cmd#delete(bufnr('%'), 1)<CR>
nnoremap <Plug>(bufstack-bury) :<C-u>call bufstack#cmd#bury(v:count ? v:count : -1)<CR>
nnoremap <Plug>(bufstack-alt) :<C-u>call bufstack#cmd#alt(-v:count1)<CR>

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
