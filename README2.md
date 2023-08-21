A Vim Plugin for Lively Previewing LaTeX PDF Output (vim-zathura-synctex)
=========================================================================

This is a modified copy of the 
[original plugin](https://github.com/xuhdev/vim-latex-live-preview)
which provides a live preview of the output PDF of your LaTeX file. 
I quote: 
"The display of the output PDF file will be updated lively as you type (just hold
the cursor and you will see the PDF file updated). Currently,
vim-latex-live-preview only support UNIX-like systems."

The modification consists in enabling Forward and Inverse searches
between `vim` and the [zathura pdf viewer](https://pwmt.org/projects/zathura/).




Table of Contents
-----------------

- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Known issues and Limitations](#known-issues)
- [Screenshot](#screenshot)




Installation
------------

Before installing, you need to make sure your Vim version is later than 7.3,
and is compiled with `+python` feature.
Furthermore, install the [zathura pdf viewer](https://pwmt.org/projects/zathura/).
Here are two ways to install this version of the plugin.

### [Vundle](https://github.com/VundleVim/Vundle.vim)

Add the plugin in the Vundle section of your `~/.vimrc`:

```vim
call vundle#begin()
[...]
" A Vim Plugin for Lively Previewing LaTeX PDF Output
Plugin 'andreas-wachtel/vim-latex-live-preview'
[...]
call vundle#end()
```

Then reload the config and install the new plugin. Run inside `vim`:

```vim
:so ~/.vimrc
:PluginInstall
```

### Manually

Copy `plugin/latexlivepreview.vim` to `~/.vim/plugin`.



Usage
-----

Simply execute `:LLPStartPreview` to launch the previewer. Then try to type in
Vim and you should see the live update. The updating time could be set by Vim's
['updatetime'][] option. If your pdf viewer crashes when updates happen, you can
try to set 'updatetime' to a higher value to make it update less frequently. The
suggested value of 'updatetime' is `1000`.

If the root file is not the file you are currently editing, you can specify it
by executing `:LLPStartPreview <root-filename>` or executing `:LLPStartPreview`
with the following declaration in the first line of your source file:

```latex
% !TEX root = <root-filename>
```

The path to the root file can be an absolute path or a relative path, in which
case it is **relative to the parent directory of the current file**.

:warning: if `<root-filename>` contains special characters (such as space), they
must be escaped manually.



Configuration
-------------

DONE: enable latexmk funcion (in code)  
TODO: describe in readme: what to put in .vimrc  to make it use latexmk.
TODO: describe in readme: how to setup backward (zathura config) and forward search (.vimrc config)
TODO: describe in readme: zathura with history in temp. directory.
TODO: mention in readme: that latexmk takes care of  bibtex  and  makeindex  compilations. 
  Therefore, some bugs of the original plugin are solved.

TODO: If you want to use pdflatex (without latexmk) and use synctex please go to the secondary branch.
There is a need, to update the synctex file (which is done  automatically by latexmk, but not by pdflatex)




TODO: restore
`stat -c '%Y' filename`

### Option A: PDF viewer and TeX engine and Synctex support
At the moment of writing the version of 'vim-latex-live-preview' contained in this fork is needed.
For the setup details see [my gist](https://gist.github.com/andreas-wachtel/1025a7d2c246af267da2b84234f57d3f).
I still intent to put a screen-cast.


### Option B: PDF viewer and TeX engine (without synctex)
See [original plugin](https://github.com/xuhdev/vim-latex-live-preview)


### TeX Inputs

TeX engines use the environment variable `TEXINPUTS` to search for packages and
input files (`\usepackage{pkg}` or `\input{filename}`). LLP passes this
environment variable to the compiler by default.  The default can be overridden
by setting the `g:livepreview_texinputs` variable:

```vim
let g:livepreview_texinputs = '/path1/to/files//:/path2/to/files//'
```

Note:  The double trailing `/` tells the compiler to search subdirectories.


### Bibliography executable

`LLP` uses `bibtex` as the default executable to process `.bib` files. This can
be overridden by setting the `g:livepreview_use_biber` variable.

```vim
let g:livepreview_use_biber = 1
```

Please note that the package `biblatex` can use both `bibtex` and the newer
`biber`, but uses `biber` by default. To use `bibtex`, add `backend=bibtex`
to your `biblatex` usepackage declaration.

```latex
\usepackage[backend=bibtex]{biblatex}
```

Please note that `biblatex` will NOT work straight out of the box, you will
need to set either `g:livepreview_use_biber` or `backend=bibtex`, but not both.


### Autocmd

By default, the LaTeX sources will be recompiled each time the buffer is written
to disk, but also when the cursor holds. To prevent recompilation on cursor
hold (autocmd events `CursorHold` and `CursorHoldI`), use the feature flag:

```vim
let g:livepreview_cursorhold_recompile = 0
```


Known issues and Limitations
----------------------------

For the moment, the issues are the same as those of the original plugin (from xuhdev)
listed on [known issues](https://github.com/xuhdev/vim-latex-live-preview#known-issues).


### other viewers
Currently, I cannot get synctex to work between `vim` and the snap version of `evince`.
I reported the [issue](https://bugs.launchpad.net/ubuntu/+source/snapd/+bug/2031259).




Screenshot
----------

![Screenshot with Evince](misc/screenshot-evince.gif)

<!--
The screenshot is at ./misc/screenshot-evince.gif
-->

['updatetime']: http://vimdoc.sourceforge.net/htmldoc/options.html#%27updatetime%27
[evince]: http://projects.gnome.org/evince/
[okular]: http://okular.kde.org/
