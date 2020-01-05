" ___vital___
" NOTE: lines between '" ___vital___' is generated by :Vitalize.
" Do not modify the code nor insert new lines before '" ___vital___'
function! s:_SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
endfunction
execute join(['function! vital#_trea#Vim#Window#Locator#import() abort', printf("return map({'focus': '', 'get_thresholds': '', 'is_suitable': '', 'find': '', 'set_thresholds': '', 'attach': '', 'detach': ''}, \"vital#_trea#function('<SNR>%s_' . v:key)\")", s:_SID()), 'endfunction'], "\n")
delfunction s:_SID
" ___vital___
let s:UNIQUE = sha256(expand('<sfile>:p'))

let s:winwidth_threshold = &columns / 4
let s:winheight_threshold = &lines / 3

function! s:get_thresholds() abort
  return {
        \ 'winwidth': s:winwidth_threshold,
        \ 'winheight': s:winheight_threshold,
        \}
endfunction

function! s:set_thresholds(thresholds) abort
  let s:winwidth_threshold = get(a:thresholds, 'winwidth', s:winwidth_threshold)
  let s:winheight_threshold = get(a:thresholds, 'winheight', s:winheight_threshold)
endfunction

function! s:find(origin) abort
  let nwinnr = winnr('$')
  if nwinnr == 1
    return 1
  endif
  let origin = a:origin == 0 ? winnr() : a:origin
  let former = range(origin, winnr('$'))
  let latter = reverse(range(1, origin - 1))
  for winnr in (former + latter)
    if s:is_suitable(winnr)
      return winnr
    endif
  endfor
  return 0
endfunction

function! s:focus(origin) abort
  let winnr = s:find(a:origin)
  if winnr == 0 || winnr == winnr()
    return 1
  endif
  call win_gotoid(win_getid(winnr))
endfunction

function! s:attach() abort
  execute printf('augroup vital_window_locator_local_internal_%s', s:UNIQUE)
    execute 'autocmd! * <buffer>'
    execute 'autocmd WinLeave <buffer> call s:_on_WinLeave()'
  execute 'augroup END'
endfunction

function! s:detach() abort
  execute printf('augroup vital_window_locator_local_internal_%s', s:UNIQUE)
    autocmd! * <buffer>
  execute 'augroup END'
endfunction

function! s:is_suitable(winnr) abort
  if getbufvar(winbufnr(a:winnr), '&previewwindow')
        \ || winwidth(a:winnr) < s:winwidth_threshold
        \ || winheight(a:winnr) < s:winheight_threshold
    return 0
  endif
  return 1
endfunction

function! s:_on_WinLeave() abort
  let s:info = {
        \ 'nwin': winnr('$'),
        \ 'previous': win_getid(winnr('#'))
        \}
endfunction

function! s:_on_WinEnter() abort
  if exists('s:info') && winnr('$') < s:info.nwin
    call s:focus(win_id2win(s:info.previous) || winnr())
  endif
  silent! unlet! s:info
endfunction

execute printf('augroup vital_window_locator_internal_%s', s:UNIQUE)
  execute 'autocmd! *'
  execute 'autocmd WinEnter * nested call s:_on_WinEnter()'
execute 'augroup END'