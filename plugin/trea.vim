if exists('g:trea_loaded')
  finish
endif
let g:trea_loaded = 1

augroup trea_internal
  autocmd! *
  autocmd BufReadCmd trea:*/* nested call trea#internal#viewer#init()
augroup END

let g:trea_debug = get(g:, 'trea_debug', 0)
