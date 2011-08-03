func! vundle#installer#new(bang, ...) abort
  let bundles = (a:1 == '') ?
        \ s:reload_bundles() :
        \ map(copy(a:000), 'vundle#config#init_bundle(v:val, {})')

  let names = map(copy(bundles), 'v:val.name_spec')
  call s:display(['" Installing'], names)

  exec ":1"
  redraw!

  for l in range(1,len(names))
    exec ":+1"
    redraw!
    exec ':norm i'
    sleep 1m
  endfor

  redraw!

  let helptags = vundle#installer#helptags(bundles)
  echo 'Done! Helptags: '.len(helptags).' bundles processed'
endf

func! s:display(headers, results)
  if !exists('s:browse') | let s:browse = tempname() | endif
  let results = map(a:results, ' printf("Bundle! ' ."'%s'".'", v:val) ')
  call writefile(a:headers + results, s:browse)
  silent pedit `=s:browse`

  wincmd P | wincmd H

  setl ft=vundle
  call vundle#scripts#setup_view()
endf

func! vundle#installer#install(bang, name) abort
  if !isdirectory(g:bundle_dir) | call mkdir(g:bundle_dir, 'p') | endif

  let b = vundle#config#init_bundle(a:name, {})

  echo 'Installing '.b.name

  let [err_code, status] = s:sync(a:bang, b)

  redraw!

  if 0 == err_code
    if 'ok' == status 
      echo b.name.' installed'
      exe ":sign place ".line('.')." line=".line('.')." name=VuOk buffer=" . bufnr("$")
    elseif 'skip' == status
      echo b.name.' already installed'
      exe ":sign place ".line('.')." line=".line('.')." name=VuOk buffer=" . bufnr("$")
    endif
  else
    echohl Error
    echo 'Error installing "'.b.name
    echohl None
    exe ":sign place ".line('.')." line=".line('.')." name=VuEr buffer=" . bufnr("$")
    sleep 1
  endif
endf

func! vundle#installer#helptags(bundles) abort
  let bundle_dirs = map(copy(a:bundles),'v:val.rtpath()')
  let help_dirs = filter(bundle_dirs, 's:has_doc(v:val)')
  call map(copy(help_dirs), 's:helptags(v:val)')
  return help_dirs
endf

func! vundle#installer#clean(bang) abort
  let bundle_dirs = map(copy(g:bundles), 'v:val.path()') 
  let all_dirs = split(globpath(g:bundle_dir, '*'), "\n")
  let x_dirs = filter(all_dirs, '0 > index(bundle_dirs, v:val)')

  if empty(x_dirs)
    echo "All clean!"
    return
  end

  if (a:bang || input('Are you sure you want to remove '.len(x_dirs).' bundles? [ y/n ]:') =~? 'y')
    let cmd = (has('win32') || has('win64')) ?
    \           'rmdir /S /Q' :
    \           'rm -rf'
    exec '!'.cmd.' '.join(map(x_dirs, 'shellescape(v:val)'), ' ')
  endif
endf

func! s:reload_bundles()
  " TODO: obtain Bundles without sourcing .vimrc
  if filereadable($MYVIMRC)| silent source $MYVIMRC | endif
  if filereadable($MYGVIMRC)| silent source $MYGVIMRC | endif
  return g:bundles
endf

func! s:has_doc(rtp) abort
  return isdirectory(a:rtp.'/doc')
  \   && (!filereadable(a:rtp.'/doc/tags') || filewritable(a:rtp.'/doc/tags'))
  \   && !(empty(glob(a:rtp.'/doc/*.txt')) && empty(glob(a:rtp.'/doc/*.??x')))
endf

func! s:helptags(rtp) abort
  try
    helptags `=a:rtp.'/doc/'`
  catch
    echohl Error | echo "Error generating helptags in ".a:rtp | echohl None
  endtry
endf

func! s:sync(bang, bundle) abort
  let git_dir = expand(a:bundle.path().'/.git/')
  if isdirectory(git_dir)
    if !(a:bang) | return [0, 'skip'] | endif
    let cmd = 'cd '.shellescape(a:bundle.path()).' && git pull'

    if (has('win32') || has('win64'))
      let cmd = substitute(cmd, '^cd ','cd /d ','')  " add /d switch to change drives
      let cmd = '"'.cmd.'"'                          " enclose in quotes
    endif
  else
    let cmd = 'git clone '.a:bundle.uri.' '.shellescape(a:bundle.path())
  endif

  call s:system(cmd)

  if 0 != v:shell_error
    return [v:shell_error, 'error']
  end
  return [0, 'ok']
endf

func! s:system(cmd) abort
  let output = system(a:cmd)
  call s:log(output)
endf

func! s:log(str) abort
  if !exists('g:vundle_log') | let g:vundle_log = [] | endif
  call add(g:vundle_log, a:str)
endf
