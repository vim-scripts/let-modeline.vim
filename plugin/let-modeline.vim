"
" example -> VIM: let b:toto="foo" g:tata=4 g:egal="t=y".&tw
" ===========================================================================
" File:		let-modeline.vim
" Author:	Luc Hermitte <EMAIL:hermitte@free.fr>
" 		<URL:http://hermitte.free.fr/vim/>
" Version:	1.1
" Last Update:	13th sep 2001 
"
" Purpose:	Defines the function : FirstModeLine() that extends the VIM
" 		modeline feature to variables. In VIM, it is possible to
" 		set options in the last line.  -> :h modeline
" 		The function proposed extends it to 'let {var}={val}'
" 		affectations.
"
" TODO:		* Enforce the patterns and the resulting errors
" 		* Permit to have comments ending characters at the end of
" 		  the line.
" 		* Parse several modelines
" 		* Accept options setting (VIM way)
"
" Exemple of a useful aplication: 
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
"
" ===========================================================================
"
" Format:	On the _first_ line of any file, the extended modeline
" 		format is :
" 		{line} 		::= [text]{white}vim:[white]let{affectations}
" 		{affectations}	::= {sgl_affect.}
" 		{affectations}	::= {sgl_affect.}{white}{affectations}
" 		{sgl_affect.}	::= {variable}[white]=[white]{value}
" 		{variable}	::= cf. vim variable format ; beware simple
" 				    variables (neither global nor buffer
" 				    relative) are not exported.
" 		{value}		::= string or numeral value : no function
" 				    call allowed.
" 		
" Options:	* b:ModeLine_CallBack(var,val) : callback function
" 		  Enable to define callback functions when needed.
" 		  cf. lhlatex.vim
"
" Remark:	The only way to call a function is through the callback
" 		feature. Affectation like 'let g:foo="abc".DEF()' are
" 		recognized and forbiden.
" 		
" ===========================================================================
"
" Internal function dedicated to the recognition of function calls
function! FML_foundFunctionCall(value_str)
  let str = substitute(a:value_str, '"[^"]*"', '', 'g')
  let str = substitute(str, "'[^']*'", '', 'g')
  return match(str, '(.*)') != -1
endfunction

" The main function
function! FirstModeLine()
  let line1 = getline( 1 )
  let startline = '[vV][iI][mM]:\s*let'
  let mtch  = matchstr( line1, startline . '.*$' )
  if mtch !=""
    let mtch  = substitute( mtch, startline, '', '' )
    let re_var   = '\s\+\([[:alnum:]:]\+\)'
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


"
" ===========================================================================
" Example of a callback function
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
