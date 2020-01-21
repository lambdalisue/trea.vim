let s:Lambda = vital#trea#import('Lambda')
let s:AsyncLambda = vital#trea#import('Async.Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

let s:CancellationTokenSource = vital#trea#import('Async.CancellationTokenSource')
let s:STATUS_NONE = g:trea#internal#node#STATUS_NONE
let s:STATUS_COLLAPSED = g:trea#internal#node#STATUS_COLLAPSED
let s:STATUS_EXPANDED = g:trea#internal#node#STATUS_EXPANDED

function! trea#core#init(uri, provider, ...) abort
  doautocmd <nomodeline> User TreaInitPre
  setlocal buftype=nofile bufhidden=unload
  setlocal noswapfile nobuflisted nomodifiable
  setlocal signcolumn=yes:1
  setlocal filetype=trea


  augroup trea_core_internal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> setlocal nobuflisted
    autocmd CursorMoved,CursorMovedI <buffer> let b:trea_cursor = getcurpos()
    autocmd BufReadCmd <buffer> nested call s:BufReadCmd()
    autocmd ColorScheme <buffer> call s:ColorScheme()
  augroup END

  let options = extend({
        \ 'reveal': [],
        \ 'comparator': trea#comparator#default#new(),
        \}, a:0 ? a:1 : {},
        \)
  let trea = {
        \ 'bufnr': bufnr('%'),
        \ 'source': s:CancellationTokenSource.new(),
        \ 'provider': a:provider,
        \ 'comparator': options.comparator,
        \ 'marks': [],
        \ 'hidden': 0,
        \ 'pattern': '',
        \}
  let root = trea#internal#node#new(a:provider.get_node(a:uri))
  let trea.root = root
  let trea.nodes = [root]
  let b:trea = trea
  doautocmd <nomodeline> User TreaInit

  call trea#internal#spinner#start(trea.bufnr)
  call trea#internal#renderer#highlight()
  call trea#internal#renderer#syntax()
  call trea#internal#mapping#init()
  call trea#lib#action#init('trea-')
  doautocmd <nomodeline> User TreaReady

  return s:Promise.resolve()
        \.then({ -> trea#core#expand(trea, trea.root) })
        \.then({ -> trea#core#reveal(trea, options.reveal) })
endfunction

function! trea#core#get(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  return getbufvar(bufnr, 'trea', v:null)
endfunction

function! trea#core#get_node(trea, lnum) abort
  return get(a:trea.nodes, a:lnum - 1, v:null)
endfunction

function! trea#core#get_cursor_node(trea) abort
  let info = getbufinfo(a:trea.bufnr)
  if empty(info)
    return v:null
  endif
  return trea#core#get_node(a:trea, info[0].lnum)
endfunction

function! trea#core#get_marked_nodes(trea) abort
  let ms = a:trea.marks
  return filter(
        \ copy(a:trea.nodes),
        \ { _, v -> index(ms, v.__key) isnot# -1 },
        \)
endfunction

function! trea#core#get_selected_nodes(trea) abort
  if empty(a:trea.marks)
    return [trea#core#get_cursor_node(a:trea)]
  endif
  return trea#core#get_marked_nodes(a:trea)
endfunction

function! trea#core#cancel(trea) abort
  call a:trea.source.cancel()
  let a:trea.source = s:CancellationTokenSource.new()
  return trea#core#redraw(a:trea)
endfunction

function! trea#core#redraw(trea) abort
  return trea#internal#renderer#render(a:trea.nodes, a:trea.marks)
        \.then({ v -> trea#lib#buffer#replace(a:trea.bufnr, v) })
endfunction

function! trea#core#cursor(winid, trea, key, ...) abort
  let options = extend({
        \ 'offset': 0,
        \ 'previous': v:null
        \}, a:0 ? a:1 : {})
  let index = trea#internal#node#index(a:key, a:trea.nodes)
  if index is# -1
    if a:key != a:trea.root.__key
      return trea#core#cursor(a:winid, a:trea, a:key[:-2], options)
    endif
    return s:Promise.reject(printf('a node %s does not exist', a:key))
  endif
  let cursor = s:WindowCursor.get_cursor(a:winid)
  if options.previous is# v:null || options.previous == cursor
    call s:WindowCursor.set_cursor(a:winid, [index + 1 + options.offset, cursor[1]])
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#reload(trea, node) abort
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#reload(
        \   a:node,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#expand(trea, node) abort
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#expand(
        \   a:node,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#collapse(trea, node) abort
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#collapse(
        \   a:node,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#reveal(trea, key) abort
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#reveal(
        \   a:key,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#enter(trea, node) abort
  if a:node.status is# s:STATUS_NONE
    return s:Promise.reject()
  endif
  return s:Promise.resolve(a:node)
        \.then({ n -> s:enter(a:trea, n) })
endfunction

function! trea#core#leave(trea) abort
  return s:Promise.resolve(a:trea.root)
        \.then({ root -> trea#internal#node#parent(
        \   root,
        \   a:trea.provider,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ n -> s:enter(a:trea, n) })
endfunction

function! trea#core#mark_on(trea, node) abort
  let key = a:node.__key
  if index(a:trea.marks, key) is# -1
    call add(a:trea.marks, key)
    return trea#core#redraw(a:trea)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#mark_off(trea, node) abort
  let key = a:node.__key
  let index = index(a:trea.marks, key)
  if index isnot# -1
    call remove(a:trea.marks, index)
    return trea#core#redraw(a:trea)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#mark_toggle(trea, node) abort
  let key = a:node.__key
  if index(a:trea.marks, key) is# -1
    return trea#core#mark_on(a:trea, a:node)
  endif
  return trea#core#mark_off(a:trea, a:node)
endfunction

function! trea#core#hidden_on(trea) abort
  if !a:trea.hidden
    let a:trea.hidden = 1
    return trea#core#reload(a:trea, a:trea.root)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#hidden_off(trea) abort
  if a:trea.hidden
    let a:trea.hidden = 0
    return trea#core#reload(a:trea, a:trea.root)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#hidden_toggle(trea) abort
  if a:trea.hidden
    return trea#core#hidden_off(a:trea)
  endif
  return trea#core#hidden_on(a:trea)
endfunction

function! trea#core#filter(trea, pattern) abort
  if a:trea.pattern !=# a:pattern
    let a:trea.pattern = a:pattern
    return trea#core#reload(a:trea, a:trea.root)
  endif
  return s:Promise.resolve()
endfunction

function! s:BufReadCmd() abort
  let trea = trea#core#get()
  let winid = win_getid()
  let cursor = get(b:, 'trea_cursor', getcurpos())
  call trea#internal#renderer#syntax()
  call trea#core#redraw(trea)
        \.then({ -> s:WindowCursor.set_cursor(winid, cursor[1:2]) })
        \.then({ -> trea#core#reload(trea, trea.root) })
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:ColorScheme() abort
  let trea = trea#core#get()
  call trea#internal#renderer#highlight()
endfunction

function! s:update_nodes(trea, nodes) abort
  let a:trea.nodes = copy(a:nodes)
  let Hidden = a:trea.hidden
        \ ? { -> 1 }
        \ : { v -> v.status is# s:STATUS_EXPANDED || !v.hidden }
  let Filter = empty(a:trea.pattern)
        \ ? { -> 1 }
        \ : { v -> v.status is# s:STATUS_EXPANDED || v.name =~ a:trea.pattern }
  return s:Promise.resolve(a:trea.nodes)
        \.then({ ns -> s:AsyncLambda.filter(ns, Hidden) })
        \.then({ ns -> s:AsyncLambda.filter(ns, Filter) })
        \.then({ ns -> s:Lambda.pass(ns, s:Lambda.let(a:trea, 'nodes', ns)) })
        \.then({ -> s:update_marks(a:trea, a:trea.marks) })
endfunction

function! s:update_marks(trea, marks) abort
  return s:Promise.resolve(a:trea.nodes)
        \.then({ ns -> s:AsyncLambda.map(ns, { v -> v.__key }) })
        \.then({ ks -> s:AsyncLambda.filter(a:marks, { v -> index(ks, v) isnot# -1 }) })
        \.then({ ms -> s:Lambda.let(a:trea, 'marks', ms) })
endfunction

function! s:enter(trea, node) abort
  if !has_key(a:node, 'bufname')
    return s:Promise.reject('the node does not have bufname attribute')
  endif
  noautocmd execute printf('edit %s', a:node.bufname)
  let uri = trea#uri(a:node.bufname)
  let proto = trea#proto(uri)
  let provider = trea#proto#{proto}#provider#new()
  return trea#core#init(uri, provider, {
        \ 'comparator': a:trea.comparator,
        \})
endfunction


augroup trea_core_internal
  autocmd! *
  autocmd User TreaInitPre :
  autocmd User TreaInit :
  autocmd User TreaReady :
augroup END
