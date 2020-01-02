" load guard {{{1

if exists('g:autoloaded_man')
  finish
endif
let g:autoloaded_man = 1

" }}}
" variable initialization {{{1

let s:man_tag_depth = 0

" }}}
" man#get_page {{{1

function! man#get_page(split_type, ...)
  if a:0 == 0
    call s:handle_nroff_file_or_error(a:split_type)
    return
  elseif a:0 == 1
    let l:sect = ''
    let l:page = a:1
  elseif a:0 >= 2
    let l:sect = a:1
    let l:page = a:2
  endif

  if l:sect !=# '' && !s:manpage_exists(l:sect, l:page)
    let l:sect = ''
  endif
  if !s:manpage_exists(l:sect, l:page)
    call man#helpers#error("No manual entry for '".l:page."'.")
    return
  endif

  " Remember current windows and number of windows
  let l:prevwin=winnr()
  let l:maxwin=winnr('$')

  call s:update_man_tag_variables()
  call s:get_new_or_existing_man_window(a:split_type)
  call man#helpers#set_manpage_buffer_name(l:page, l:sect)
  call man#helpers#load_manpage_text(l:page, l:sect)

  " Try to return to the original window, taking into account
  " if the total number of windows increased, and the previous window
  " is below the newly inserted window
  if a:split_type == 'horizontal'
    if l:maxwin < winnr('$')
      if l:prevwin < winnr()
        execute l:prevwin . 'wincmd w'
      else
        execute l:prevwin+1 . 'wincmd w'
      endif
    else
      execute l:prevwin . 'wincmd w'
    endif
  else
    execute l:prevwin . 'wincmd w'
  endif
endfunction

function! s:manpage_exists(sect, page)
  if a:page ==# ''
    return 0
  endif
  let l:find_arg = man#helpers#find_arg()
  let l:where = system(g:vim_man_cmd.' '.l:find_arg.' '.man#helpers#get_cmd_arg(a:sect, a:page))
  if l:where !~# '^\s*/'
    " result does not look like a file path
    return 0
  else
    " found a manpage
    return 1
  endif
endfunction

" }}}
" :Man command in nroff files {{{1

" handles :Man command invocation with zero arguments
function! s:handle_nroff_file_or_error(split_type)
  " :Man command can be invoked in 'nroff' files to convert it to a manpage
  if &filetype ==# 'nroff'
    if filereadable(expand('%'))
      return s:get_nroff_page(a:split_type, expand('%:p'))
    else
      return man#helpers#error("Can't open file ".expand('%'))
    endif
  else
    " simulating vim's error when not enough args provided
    return man#helpers#error('E471: Argument required')
  endif
endfunction

" open a nroff file as a manpage
function! s:get_nroff_page(split_type, nroff_file)
  call s:update_man_tag_variables()
  call s:get_new_or_existing_man_window(a:split_type)
  silent exec 'edit '.fnamemodify(a:nroff_file, ':t').'\ manpage\ (from\ nroff)'
  call man#helpers#load_manpage_text(a:nroff_file, '')
endfunction

" }}}
" man#get_page_from_cword {{{1

function! man#get_page_from_cword(split_type, cnt)
  if a:cnt == 0
    let l:old_isk = &iskeyword
    if &filetype ==# 'man'
      " when in a manpage try determining section from a word like this 'printf(3)'
      setlocal iskeyword+=(,),:
    endif
    let l:str = expand('<cword>')
    let &l:iskeyword = l:old_isk
    let l:page = matchstr(l:str, '\(\k\|:\)\+')
    let l:sect = matchstr(l:str, '(\zs[^)]*\ze)')
    if l:sect !~# '^[0-9nlpo][a-z]*$' || l:sect ==# l:page
      let l:sect = ''
    endif
  else
    let l:sect = a:cnt
    let l:old_isk = &iskeyword
    setlocal iskeyword+=:
    let l:page = expand('<cword>')
    let &l:iskeyword = l:old_isk
  endif
  call man#get_page(a:split_type, l:sect, l:page)
endfunction

" }}}
" man#pop_page {{{1

function! man#pop_page()
  if s:man_tag_depth <= 0
    return
  endif
  let s:man_tag_depth -= 1
  let buffer = s:man_tag_buf_{s:man_tag_depth}
  let line   = s:man_tag_lin_{s:man_tag_depth}
  let column = s:man_tag_col_{s:man_tag_depth}
  " jumps to exact buffer, line and column
  exec buffer.'b'
  exec line
  exec 'norm! '.column.'|'
  unlet s:man_tag_buf_{s:man_tag_depth}
  unlet s:man_tag_lin_{s:man_tag_depth}
  unlet s:man_tag_col_{s:man_tag_depth}
endfunction

" }}}
" script local helpers {{{1

function! s:update_man_tag_variables()
  let s:man_tag_buf_{s:man_tag_depth} = bufnr('%')
  let s:man_tag_lin_{s:man_tag_depth} = line('.')
  let s:man_tag_col_{s:man_tag_depth} = col('.')
  let s:man_tag_depth += 1
endfunction

function! s:get_new_or_existing_man_window(split_type)
  if &filetype != 'man'
    let thiswin = winnr()
    exec "norm! \<C-W>b"
    if winnr() > 1
      exec 'norm! '.thiswin."\<C-W>w"
      while 1
        if &filetype == 'man'
          break
        endif
        exec "norm! \<C-W>w"
        if thiswin == winnr()
          break
        endif
      endwhile
    endif
    if &filetype != 'man'
      if a:split_type == 'vertical'
        vnew
      elseif a:split_type == 'tab'
        tabnew
      else
        new
      endif
    endif
  endif
endfunction

" }}}
" vim:set ft=vim et sw=2:
