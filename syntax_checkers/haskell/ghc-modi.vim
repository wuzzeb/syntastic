"============================================================================
"File:        ghc-modi.vim
"Description: Syntax checking plugin for syntastic.vim
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================

if exists('g:loaded_syntastic_haskell_ghc_modi_checker')
    finish
endif
let g:loaded_syntastic_haskell_ghc_modi_checker = 1

let s:save_cpo = &cpo
set cpo&vim

" Map where the key is the root directory and the value is the process object.
let s:ghc_modi_procs = {}

" Map where the key is the filename and the value is the root directory.
" This is essentially just a cache of the output of `ghc-mod root`.
let s:ghc_modi_roots = {}

function! SyntaxCheckers_haskell_ghc_modi_GetLocList() dict
    let ghcmodi_prog = self.makeprgBuild({ 'exe': self.getExecEscaped() . ' --boundary="\n "' })

    let fullfile = expand("%:p")

    if has_key(s:ghc_modi_roots, fullfile)
        let root = s:ghc_modi_roots[fullfile]
    else
        let root = system("cd '" . expand("%:p:h") . "'; ghc-mod root")
        let s:ghc_modi_roots[fullfile] = root
    endif

    if has_key(s:ghc_modi_procs, root)
        let proc = s:ghc_modi_procs[root]
    else
        let olddir = getcwd()
        exec "lcd " . root
        let proc = vimproc#popen2(ghcmodi_prog)
        exec "lcd " . olddir
        let s:ghc_modi_procs[root] = proc
    endif

    call proc.stdin.write("check " . fullfile . "\n")

    let found_end = 0
    let errors = []
    let curbuf = bufnr('')

    while found_end == 0
        for line in proc.stdout.read_lines()
            if line == "OK"
                let found_end = 1
            elseif line =~ "^NG "
                call add(errors, {"text": line, "bufnr": 0, "valid": 1, "lnum":0})
                let found_end = 1
            elseif len(line) > 0
                if line[0] == " "
                    "Continuation line
                    call add(errors, {"text": line[1:], "bufnr": 0, "valid": 1, "lnum":0})
                else
                    "Start of an error
                    let matches = matchlist(line, '\m\([^:]\+\):\(\d\+\):\(\d\+\):\(.*\)')
                    if len(matches) >= 5
                        let err = {}
                        let err.lnum = matches[2]
                        let err.col = matches[3]
                        let err.text = matches[4]
                        let err.bufnr = curbuf
                        let err.valid = 1
                        if err.text[0:6] == "Warning"
                            let err.type = "W"
                        else
                            let err.type = "E"
                        endif
                        call add(errors, err)
                    endif
                endif
            endif
        endfor
    endwhile

    "Check for program status
    if proc.checkpid()[0] !=# "run"
        unlet s:ghc_modi_procs[root]
    endif

    return errors
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'haskell',
    \ 'name': 'ghc_modi',
    \ 'exec': 'ghc-modi' })

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set et sts=4 sw=4:
