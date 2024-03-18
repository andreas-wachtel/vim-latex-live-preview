" Copyright (C) 2012 Hong Xu

" This file is part of vim-live-preview.

" vim-live-preview is free software: you can redistribute it and/or modify it
" under the terms of the GNU General Public License as published by the Free
" Software Foundation, either version 3 of the License, or (at your option)
" any later version.

" vim-live-preview is distributed in the hope that it will be useful, but
" WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
" or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
" more details.

" You should have received a copy of the GNU General Public License along with
" vim-live-preview.  If not, see <http://www.gnu.org/licenses/>.


if v:version < 700
    finish
endif

" Check whether this script is already loaded
if exists("g:loaded_vim_live_preview")
    finish
endif
let g:loaded_vim_live_preview = 1

" Check mkdir feature
if (!exists("*mkdir"))
    echohl ErrorMsg
    echo 'vim-latex-live-preview: mkdir functionality required'
    echohl None
    finish
endif

" Setup python
if (has('python3'))
    let s:py_exe = 'python3'
elseif (has('python'))
    let s:py_exe = 'python'
else
    echohl ErrorMsg
    echo 'vim-latex-live-preview: python required'
    echohl None
    finish
endif

let s:saved_cpo = &cpo
set cpo&vim

let s:previewer = ''

" Run a shell command in background
function! s:RunInBackground(cmd)

execute s:py_exe "<< EEOOFF"

try:
    subprocess.Popen(
            vim.eval('a:cmd'),
            shell = True,
            universal_newlines = True,
            stdout=open(os.devnull, 'w'), stderr=subprocess.STDOUT)

except:
    pass
EEOOFF

endfunction


function! UpdateLiveSynctex()
	if !g:livepreview_use_latexmk

		" ADDITIONAL requirement 'stat' command.
		" I changed the variables to global variables, because in a secondary .tex
		" file there is no access to   b:livepreview_buf_data

	    let l:newdate = system("stat -c '%Y' ".g:livepreview_tmpSynctex.".gz")
	
		if g:syncdate < l:newdate
			" If the above inequality is satisfied, then the synctex has been
			" updated. Hence, we have to change it again to do de reverse /
			" forward search.
	
	        " The following established the source file name in the synctex.gz file.
	        " unzip -> sed change tex-source in synctex -> zip
	        silent call system("gzip -d " . g:livepreview_tmpSynctex.".gz")
	
	        silent call system("sed -i -e '2s+^.*$+Input:1:" . g:livepreview_texRoot . "+' " . g:livepreview_tmpSynctex)
	
	        silent call system("gzip " . g:livepreview_tmpSynctex)
	
			echo 'synctex was updated'
	        let g:syncdate = system("stat -c '%Y' ".g:livepreview_tmpSynctex.".gz")
		endif
	endif
endfunction



function! s:Compile()

    if !exists('b:livepreview_buf_data') ||
                \ has_key(b:livepreview_buf_data, 'preview_running') == 0
        return
    endif

    " Change directory to handle properly sourced files with \input and bib
    " TODO: get rid of lcd
    execute 'lcd ' . b:livepreview_buf_data['root_dir']

    " Write the current buffer in a temporary file
	if !g:livepreview_use_latexmk
	    " only needed when NOT using latexmk
	    silent exec 'write! ' . b:livepreview_buf_data['tmp_src_file']
	end

	" Do not wait for the compilation to finish.
    call s:RunInBackground(b:livepreview_buf_data['run_cmd'])

endfunction


function! s:StartPreview(...)
    let b:livepreview_buf_data = {}

    let b:livepreview_buf_data['py_exe'] = s:py_exe

    " This Pattern Matching will FAIL for multiline biblatex declarations,
    " in which case the `g:livepreview_use_biber` setting must be respected.
    let l:general_pattern = '^\\usepackage\[.*\]{biblatex}'
    let l:specific_pattern = 'backend=bibtex'
    let l:position = search(l:general_pattern, 'cw')
    if ( l:position != 0 )
        let l:matches = matchstr(getline(l:position), specific_pattern)
        if ( l:matches == '' )
            " expect s:use_biber=1
            if ( s:use_biber == 0 )
                let s:use_biber = 1
                echohl ErrorMsg
                echom "g:livepreview_use_biber not set or does not match `biblatex` usage in your document. Overridden!"
                echohl None
            endif
        else
            " expect s:use_biber=0
            if ( s:use_biber == 1 )
                let s:use_biber = 0
                echohl ErrorMsg
                echom "g:livepreview_use_biber is set but `biblatex` is explicitly using `bibtex`. Overridden!"
                echohl None
            endif
        endif
    else
        " expect s:use_biber=0
        " `biblatex` is not being used, this usually means we
        " are using `bibtex`
        " However, it is not a universal rule, so we do nothing.
    endif


    " Create a temp directory for current buffer
    execute s:py_exe "<< EEOOFF"
vim.command("let b:livepreview_buf_data['tmp_dir'] = '" +
        tempfile.mkdtemp(prefix="vim-latex-live-preview-") + "'")
EEOOFF

    let b:livepreview_buf_data['tmp_src_file'] =
                \ b:livepreview_buf_data['tmp_dir'] .
                \ expand('%:p:r')


    " Guess the root file which will be compiled, using first the argument
    " passed, then the first line declaration of the source file and
    " eventually fallback to the current file.
    " TODO: emulate -parse-first-line properly
    let l:root_line = substitute(getline(1),
                \ '\v^\s*\%\s*!TEX\s*root\s*\=\s*(.*)\s*$',
                \ '\1', '')

    if (a:0 > 0)
        let l:root_file = fnamemodify(a:1, ':p')
    elseif (l:root_line != getline(1) && strlen(l:root_line) > 0)    " TODO: existence of `% !TEX` declaration condition must be cleaned...
        let l:root_file = fnamemodify(l:root_line, ':p')
    else
        let l:root_file = b:livepreview_buf_data['tmp_src_file']
    endif

    " Hack for complex project trees: recreate the tree in tmp_dir
    " Build tree for tmp_src_file (copy of the current buffer)
    let l:tmp_src_dir = fnamemodify(b:livepreview_buf_data['tmp_src_file'], ':p:h')
    if (!isdirectory(l:tmp_src_dir))
        silent call mkdir(l:tmp_src_dir, 'p')
    endif


    " Build tree for root_file (main tex file, which might be tmp_src_file,
    " ie. the current file)
    if (l:root_file == b:livepreview_buf_data['tmp_src_file'])       " if root file is the current file
        let l:tmp_root_dir = l:tmp_src_dir
    else
        let l:tmp_root_dir = b:livepreview_buf_data['tmp_dir'] . fnamemodify(l:root_file, ':p:h')
        if (!isdirectory(l:tmp_root_dir))
            silent call mkdir(l:tmp_root_dir, 'p')
        endif
    endif
	

    " Escape pathnames
    let l:root_file = fnameescape(l:root_file)
    let l:tmp_root_dir = fnameescape(l:tmp_root_dir)  " NOT NEEDED (AW)
    let b:livepreview_buf_data['tmp_dir'] = fnameescape(b:livepreview_buf_data['tmp_dir'])
    let b:livepreview_buf_data['tmp_src_file'] = fnameescape(b:livepreview_buf_data['tmp_src_file'])


    " Change directory to handle properly sourced files with \input and bib
    " TODO: get rid of lcd
    if (l:root_file == b:livepreview_buf_data['tmp_src_file'])                  " if root file is the current file
        let b:livepreview_buf_data['root_dir'] = fnameescape(expand('%:p:h'))
    else
        let b:livepreview_buf_data['root_dir'] = fnamemodify(l:root_file, ':p:h')
    endif

    execute 'lcd ' . b:livepreview_buf_data['root_dir']


    let srctex = fnamemodify( b:livepreview_buf_data['tmp_src_file'], ':t:r' )
    let l:relativeTexRoot = "./" . srctex . ".tex"


	"AW: not needed when using latexmk
    " Write the current buffer in a temporary file
    "silent exec 'write! ' . b:livepreview_buf_data['tmp_src_file']

    let l:tmp_out_file = l:tmp_root_dir . '/' .
                \ fnamemodify(l:root_file, ':t:r') . '.pdf'


    let b:livepreview_buf_data['run_cmd'] =
                \ s:engine . ' ' .
                \       '-silent ' .
                \       '-shell-escape ' .
                \       '-outdir=' . l:tmp_root_dir . ' ' .
                \       '-auxdir=' . l:tmp_root_dir . ' ' .
                \       "-pdflatex='pdflatex -synctex=1' -pdf" . ' ' .
                \       l:relativeTexRoot

    silent call system(b:livepreview_buf_data['run_cmd'])
    if v:shell_error != 0
        echo 'Failed to compile'
        lcd -
        return
    endif


    " Enable compilation of bibliography:
    let l:bib_files = split(glob(b:livepreview_buf_data['root_dir'] . '/**/*.bib'))     " TODO: fails if unused bibfiles
    if len(l:bib_files) > 0
        for bib_file in l:bib_files
            let bib_fn = fnamemodify(bib_file, ':t')
            call writefile(readfile(bib_file),
                        \ l:tmp_root_dir . '/' . bib_fn)                                " TODO: may fail if same bibfile names in different dirs
        endfor

        if s:use_biber
            let s:bibexec = 'biber --input-directory=' . l:tmp_root_dir . '--output-directory=' . l:tmp_root_dir . ' ' . l:root_file
        else
            " The alternative to this pushing and popping is to write
            " temporary files to a `.tmp` folder in the current directory and
            " then `mv` them to `/tmp` and delete the `.tmp` directory.
            let s:bibexec = 'pushd ' . l:tmp_root_dir . ' && bibtex *.aux' . ' && popd'
        endif

        let b:livepreview_buf_data['run_bib_cmd'] =
                \       'env ' .
                \               'TEXMFOUTPUT=' . l:tmp_root_dir . ' ' .
                \               'TEXINPUTS=' . s:static_texinputs
                \                            . ':' . l:tmp_root_dir
                \                            . ':' . b:livepreview_buf_data['root_dir']
                \                            . ': ' .
                \ ' && ' . s:bibexec

        silent call system(b:livepreview_buf_data['run_bib_cmd'])
        silent call system(b:livepreview_buf_data['run_cmd'])
    endif
    if v:shell_error != 0
        echo 'Failed to compile bibliography'
        lcd -
        return
    endif


    call s:RunInBackground(s:previewer . ' ' . l:tmp_out_file)

    lcd -

    let b:livepreview_buf_data['preview_running'] = 1


	"
	" ADDED by Andreas Wachtel:
    " The temporary pdf file is needed as a global variable (in .vimrc) to do forwardSearch
    let g:livepreview_tmpPDFfile = l:tmp_out_file


	" 2 global variables to make updating the synctex file easy and 'robust'
	" The temporary synctex file
    let g:livepreview_tmpSynctex = b:livepreview_buf_data['tmp_src_file'].".synctex"

	" the root-file
    let srctex = fnamemodify( b:livepreview_buf_data['tmp_src_file'], ':t:r' )
    let g:livepreview_texRoot = b:livepreview_buf_data['root_dir'] . "/./" . srctex . ".tex"


	" update synctex file (first time: take date of .tex)
    let g:syncdate = system("stat -c '%Y' ".b:livepreview_buf_data['tmp_src_file'])
	call UpdateLiveSynctex()

endfunction



" Initialization code
function! s:Initialize()
	let l:ret = 0
	execute s:py_exe "<< EEOOFF"
try:
    import vim
    import tempfile
    import subprocess
    import os
except:
    vim.command('let l:ret = 1')
EEOOFF

	if l:ret != 0
		return 'Python initialization failed.'
	endif

	function! s:ValidateExecutables( context, executables )
		let l:user_set = get(g:, a:context, '')
		if l:user_set != ''
			return l:user_set
		endif
		for possible_engine in a:executables
			if executable(possible_engine)
				return possible_engine
			endif
		endfor
		echohl ErrorMsg
		echo printf("vim-latex-live-preview: The defaults for % are not executable.", a:context)
		echohl None
		throw "End execution"
	endfunction

	" Get the tex engine
	let s:engine = s:ValidateExecutables('livepreview_engine', ['pdflatex', 'xelatex', 'latexmk'])

	" Get the previewer
	let s:previewer = s:ValidateExecutables('livepreview_previewer', ['evince', 'okular', 'zathura'])

	" Initialize texinputs directory list to environment variable TEXINPUTS if g:livepreview_texinputs is not set
	let s:static_texinputs = get(g:, 'livepreview_texinputs', $TEXINPUTS)


	" a global switch to use the old function 'StartPreview' or the new one
	let s:use_latexmk = get(g:, 'livepreview_use_latexmk', 1)

	if s:use_latexmk
		" By default -synctex=1 is enabled
		let s:use_synctex = get(g:, 'livepreview_use_synctex', 1)

		" By default --shell-escape is disabled (for security)
		let s:use_shellEscape = get(g:, 'livepreview_use_shellEscape', 0)

		" Saving these variables (as globals) makes them visible to the vim-user
		" which allows to overwrite them before starting a new live-preview.
		let g:livepreview_use_latexmk = s:use_latexmk
		let g:livepreview_use_shellEscape = s:use_shellEscape
		let g:livepreview_use_synctex = s:use_synctex

	else
		" Select bibliography executable
		let s:use_biber = get(g:, 'livepreview_use_biber', 0)
	endif

	return 0
endfunction

try
    let s:init_msg = s:Initialize()
catch
    finish
endtry

if type(s:init_msg) == type('')
    echohl ErrorMsg
    echo 'vim-live-preview: ' . s:init_msg
    echohl None
endif

unlet! s:init_msg




if g:livepreview_use_latexmk
	command! -nargs=* LLPStartPreview call s:StartPreviewLatexmk(<f-args>)
else
	command! -nargs=* LLPStartPreview call s:StartPreview(<f-args>)
endif


if get(g:, 'livepreview_cursorhold_recompile', 1)
    autocmd CursorHold,CursorHoldI,BufWritePost * call s:Compile()
else
    autocmd BufWritePost * call s:Compile()
endif

let &cpo = s:saved_cpo
unlet! s:saved_cpo

" vim703: cc=80
" vim:fdm=marker et ts=4 tw=78 sw=4



function! s:StartPreviewLatexmk(...)
	let b:livepreview_buf_data = {}

	let b:livepreview_buf_data['py_exe'] = s:py_exe

	" Create a temp directory for current buffer
	execute s:py_exe "<< EEOOFF"
vim.command("let b:livepreview_buf_data['tmp_dir'] = '" +
        tempfile.mkdtemp(prefix="vim-latex-live-preview-") + "'")
EEOOFF

	" the following lines identify the rootfile
	let b:livepreview_buf_data['tmp_src_file'] =
	            \ b:livepreview_buf_data['tmp_dir'] .
	            \ expand('%:p:r')

	" Guess the root file which will be compiled, using first the argument
	" passed, then the first line declaration of the source file and
	" eventually fallback to the current file.
	" TODO: emulate -parse-first-line properly
	let l:root_line = substitute(getline(1),
	            \ '\v^\s*\%\s*!TEX\s*root\s*\=\s*(.*)\s*$',
	            \ '\1', '')

	if (a:0 > 0)
		let l:root_file = fnamemodify(a:1, ':p')
	elseif (l:root_line != getline(1) && strlen(l:root_line) > 0)    " TODO: existence of `% !TEX` declaration condition must be cleaned...
		let l:root_file = fnamemodify(l:root_line, ':p')
	else
		let l:root_file = b:livepreview_buf_data['tmp_src_file']
	endif

	"AW: This generates the absolute directory structure inside the temp-dir
	"AW: not really needed when latexmk is used. (however I kept it)
	" Hack for complex project trees: recreate the tree in tmp_dir
	" Build tree for tmp_src_file (copy of the current buffer)
	let l:tmp_src_dir = fnamemodify(b:livepreview_buf_data['tmp_src_file'], ':p:h')
	if (!isdirectory(l:tmp_src_dir))
		silent call mkdir(l:tmp_src_dir, 'p')
	endif


	" Build tree for root_file (main tex file, which might be tmp_src_file,
	" ie. the current file)
	if (l:root_file == b:livepreview_buf_data['tmp_src_file'])       " if root file is the current file
		let l:tmp_root_dir = l:tmp_src_dir
	else
		let l:tmp_root_dir = b:livepreview_buf_data['tmp_dir'] . fnamemodify(l:root_file, ':p:h')
		if (!isdirectory(l:tmp_root_dir))
			silent call mkdir(l:tmp_root_dir, 'p')
		endif
	endif

	" Escape pathnames
	let l:root_file = fnameescape(l:root_file)
	let l:tmp_root_dir = fnameescape(l:tmp_root_dir)  " NOT NEEDED (AW)
	let b:livepreview_buf_data['tmp_dir'] = fnameescape(b:livepreview_buf_data['tmp_dir'])
	let b:livepreview_buf_data['tmp_src_file'] = fnameescape(b:livepreview_buf_data['tmp_src_file'])


	" Change directory to handle properly sourced files with \input and bib
	" TODO: get rid of lcd
	if (l:root_file == b:livepreview_buf_data['tmp_src_file'])                  " if root file is the current file
		let b:livepreview_buf_data['root_dir'] = fnameescape(expand('%:p:h'))
	else
		let b:livepreview_buf_data['root_dir'] = fnamemodify(l:root_file, ':p:h')
	endif

	" Go to root directory to start latexmk with relative root-file-location.
	execute 'lcd ' . b:livepreview_buf_data['root_dir']


	if g:livepreview_use_synctex && g:livepreview_use_shellEscape
		let l:strpdf = "-pdflatex='pdflatex --shell-escape -synctex=1' -pdf"
	elseif g:livepreview_use_shellEscape
		let l:strpdf = "-pdflatex='pdflatex --shell-escape' -pdf"
	elseif g:livepreview_use_synctex
		let l:strpdf = "-pdflatex='pdflatex -synctex=1' -pdf"
	else
		let l:strpdf = '-pdf'
	endif


	" relative tex-file name in the root-directory
	let srctex = fnamemodify( b:livepreview_buf_data['tmp_src_file'], ':t:r' )
	let l:relativeTexRoot = "./" . srctex . ".tex"

	"let s:engine = 'latexmk -cd -f -interaction=batchmode'
	let b:livepreview_buf_data['run_cmd'] =
	            \ 'latexmk -cd -f'. ' ' .
	            \       '-silent ' .
	            \       '-outdir=' . l:tmp_root_dir . ' ' .
	            \       '-auxdir=' . l:tmp_root_dir . ' ' .
	            \       l:strpdf . ' ' .
	            \       l:relativeTexRoot

	silent call system(b:livepreview_buf_data['run_cmd'])
	if v:shell_error == 12
		echo 'latexmk returned 12: possibly makeindex failed'
	elseif v:shell_error != 0
		echo 'Failed to compile'
		lcd -
		return
	endif


	" AW: define the temporary PDF output as global variable, because
	" I anyway need the name (in .vimrc) to do forwardSearch
	let g:livepreview_tmpPDFfile = l:tmp_root_dir . '/' .
	            \ fnamemodify(l:root_file, ':t:r') . '.pdf'

	" start previewer
	call s:RunInBackground(s:previewer . ' ' . g:livepreview_tmpPDFfile)

	lcd -

	let b:livepreview_buf_data['preview_running'] = 1

endfunction
