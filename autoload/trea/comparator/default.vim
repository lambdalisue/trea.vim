function! trea#comparator#default#new() abort
  return { 'compare': funcref('s:comparator_compare') }
endfunction

function! s:comparator_compare(n1, n2) abort
  let k1 = a:n1.__key
  let k2 = a:n2.__key
  let t1 = a:n1.status > 0
  let t2 = a:n2.status > 0
  let l1 = len(k1)
  let l2 = len(k2)
  for index in range(0, min([l1, l2]) - 1)
    if k1[index] ==# k2[index]
      continue
    endif
    let _t1 = index + 1 is# l1 ? t1 : 1
    let _t2 = index + 1 is# l2 ? t2 : 1
    if _t1 is# _t2
      " Lexical compare
      return k1[index] > k2[index] ? 1 : -1
    else
      " Directory first
      return _t1 ? -1 : 1
    endif
  endfor
  " Shorter first
  let r = s:compare(l1, l2)
  return r is# 0 ? s:compare(!a:n1.status, !a:n2.status) : r
endfunction

function! s:compare(i1, i2) abort
  return a:i1 == a:i2 ? 0 : a:i1 > a:i2 ? 1 : -1
endfunction
