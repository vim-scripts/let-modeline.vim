"
" example -> VIM: let b:toto="foo" g:tata=4 g:egal="t=y".&tw
" ===========================================================================
" File:		let-modeline.vim {{{1
" Author:	Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
" 		<URL:http://hermitte.free.fr/vim/>
" URL: http://hermitte.free.fr/vim/ressources/dollar_VIM/plugin/let-modeline.vim
" Version:	1.3
" Last Update:	25th oct 2002
"
" Purpose:	{{{2
" 	Defines the function : FirstModeLine() that extends the VIM modeline
" 	feature to variables. In VIM, it is possible to set options in the
" 	first and last lines.  -> :h modeline
" 	The function proposed extends it to 'let {var}={val}' affectations.
"
" Exemple of a useful aplication:  {{{2
" When editing a LaTeX document composed of several files, it is very
" practical to know the name of the main file whichever file is edited --
" TKlatex does this thanks the global variable g:TeXfile. Hence it knows
" that latex should be called on this main file ; aux2tags.vim could also
" be told to compute the associated .aux file. 
" Anyway. Defining (through menus or a let command) g:TeXfile each time is
" really boring. It bored me so much that I programmed a first version of
" this script. In every file of one of my projects I added the line :
" 	% VIM: let g:TeXfile=main.tex
" [main.tex is the name of the main file of the project]
" Thus, I can very simply call LaTeX from within VIM without having to
" wonder which file is the main one nor having to specify g:TeXfile each
" time.
"
" Actually, in order to affect g:TeXfile, I have to call another function.
" Hence, I define a callback function (in my (La)TeX ftplugin) that checks
" whether I want to set g:TeXfile. In that case, the callback function
" calls the right function and return true. Otherwise, it returns false.
" You will find the code of this precise callback function as an example at
" the end of this file.
" 
" ---------------------------------------------------------------------------
" Format:	{{{2
" 	On the _first_ line of any file, the extended modeline format is:
" 		{line} 		::= [text]{white}VIM:[white]let{affectations}
" 		{affectations}	::= {sgl_affect.}
" 		{affectations}	::= {sgl_affect.}{white}{affectations}
" 		{sgl_affect.}	::= {variable}[white]=[white]{value}
" 		{variable}	::= cf. vim variable format ; beware simple
" 				    variables (neither global nor buffer
" 				    relative) are not exported.
" 		{value}		::= string or numeral value : no function
" 				    call allowed.
" 		
" Options:	{{{2
"	(*) 'modeline' : vim-option that must be set to 1
"	(*) 'modelines': vim-option corrsponding to the number of lines
"	                 searched.
"	(*) b:ModeLine_CallBack(var,val) : callback function
"	    Enable to define callback functions when needed.  cf. lhlatex.vim
"
" Installation:	{{{2
"	(*) Drop the file into your $$/plugin/ or $$/macros/ folder.
"	(*) Source it from your .vimrc and add the autocommand:
"	      " Loads FirstModeLine()
"	      if !exists('*FirstModeLine')
"		" :Runtime emules :runtime with VIM 5.x
"		Runtime plugin/let-modeline.vim
"	      endif
"	      if exists('*FirstModeLine')
"		aug ALL
"		  au!
"		  " To not interfer with Templates loaders
"		  au BufNewFile * :let b:this_is_new_buffer=1
"		  " Modeline interpretation
"		  au BufEnter * :call FirstModeLine()
"		aug END
"	      endif
"	    
" 
" Remarks:	{{{2
"	(*) The only way to call a function is through the callback feature.
"	    Affectation like 'let g:foo="abc".DEF()' are recognized and
"	    forbiden.
"	(*) The modeline is recognized thanks to "VIM" in that *must* be in
"	    uppercase letters
"
" Changes:	{{{2
"	v1.3:	Parse several lines according to &modelines and &modeline
" 	v1.2:	no-reinclusion mecanism
" 	v1.1b:	extend variable names to accept underscores
"
" Todo:		{{{2
" 	(*) Enforce the patterns and the resulting errors
"	(*) Permit to have comments ending characters at the end of the line.
" 	(*) Simplify the regexps
"
" }}}1
" ===========================================================================
" Definitions: {{{1
if !exists("g:loaded_let_modeline") 
  let g:loaded_let_modeline = 1
  "
  " Internal function dedicated to the recognition of function calls {{{2
  function! FML_foundFunctionCall(value_str)
    let str = substitute(a:value_str, '"[^"]*"', '', 'g')
    let str = substitute(str, "'[^']*'", '', 'g')
    return match(str, '(.*)') != -1
  endfunction

  " Internal function dedicated to the parsing of a line {{{2
  function! FML_parse_line(mtch)
    " call confirm('Trouve:'.a:mtch, '&ok', 1)
    if a:mtch !=""
      let mtch  = a:mtch
      let re_var   = '\s\+\([[:alnum:]:_]\+\)'
      " beware the comments ending characters
      let re_val   = '\(\(\(' . "'[^']*'" . '\)\|\("[^"]*"\)\|\([^=]\)\)*\)$' 
      let re_other = '^\(.*\)'
      let re_sub   = re_other . re_var . '\s*=\s*' . re_val 
      while strlen(mtch) != 0
	let vari = substitute( mtch, re_sub, '\2', '' )
	let valu = substitute( mtch, re_sub, '\3', '' )
	" Check : no function !
	if FML_foundFunctionCall(valu)
	  echohl ErrorMsg
	  echo "Find a function call in the affectation : let " . vari . " = " . valu
	  echohl None
	  return
	endif
	let mtch = substitute( mtch, re_sub, '\1', '' )
	""echo vari . " = " . valu . " --- " . mtch . "\n"
	if exists("b:ModeLine_CallBack")
	  exe 'let res = '. b:ModeLine_CallBack . '("'.vari.'","'.valu.'")'
	  if res == 1 | return | endif
	endif
	" Else
	execute "let " . vari . " = " . valu
      endwhile
    endif
  endfunction

  " Internal function dedicated searching the matching lines {{{2
  function! FML_do_it_on_range(first, last)
    " let modeline_pat = '[vV][iI][mM]\d*:\s*let\s*\zs.*$'
    let modeline_pat = '[vV][iI][mM]\d*:\s*let\zs.*$'
    if &verbose >= 2 " {{{
      echo a:first.','.a:last. 'g/'.modeline_pat.
	    \ '/:call FML_foundFunctionCall(matchstr(getline("."),"'.
	    \ escape(modeline_pat, '\\') .'"))'
    endif " }}}
    Silent execute a:first.','.a:last. 'g/'.modeline_pat.
	  \ '/:call FML_parse_line(matchstr(getline("."),"'.
	  \ escape(modeline_pat, '\\') .'"))'
  endfunction

  " The main function {{{2
  function! FirstModeLine()
    if !&modeline | return | endif
    let pos = line('.') . 'normal! ' . virtcol('.') . '|'
    let e1 = 1+&modelines-1
    let b2 = line('$') - &modelines+1
    " call confirm('e1='.e1."\nb2=".b2, '&ok', 1)
    if e1 >= b2
      call FML_do_it_on_range(1,  line('$'))
    else
      call FML_do_it_on_range(1,  e1)
      call FML_do_it_on_range(b2, line('$'))
    endif
    if !exists('b:this_is_new_buffer')
      exe pos
    else
      unlet b:this_is_new_buffer
    endif
    " call confirm('fini!', '&ok', 1)
  endfunction

  " }}}2
endif

" }}}1
" ===========================================================================
" Example of a callback function {{{1
" Version I use in my (La)TeX ftplugin
if 0

  let b:ModeLine_CallBack = "TeXModeLine_CallBack"
  function! TeXModeLine_CallBack(var,val)
    if match(a:var, "g:TeXfile") != -1
      " restore quotes around the file name
      "let valu  = substitute( valu, '^"\=\([[:alnum:].]\+\)"\=$', '"\1"', '' )
      call TKSetTeXfileName( 2, a:val )
      return 1
    else 
      return 0
    endif
  endfunction

endif
" }}}1
" ===========================================================================
" vim600: set fdm=marker:
