" vim600: set foldmethod=marker:
"
" p4 extension for VCSCommand.
"
" Version:       VCS development
" Maintainer:    Jeff Thomas <jeffdthomas@gmail.com>
" License:
" Copyright (c) 2010 Jeff Thomas
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.
"
" Section: Documentation {{{1
"
" Command documentation {{{2
"
" The following commands only apply to files under Perforce source control.
"
" PFEdit               Performs "p4 edit" on the current file.
"
" PFIntegrate          Performs "p4 integrate" on the current file and the
"                      passed argument.
"   
" PFChange             Wrapper for "p4 change"
"
"   
" Options documentation: {{{2
"
" VCSCommandP4Exec
"   This variable specifies the p4 executable.  If not set, it defaults to
"   'p4' executed from the user's executable path.
"
" VCSCommandP4DiffOpt
"   This variable, if set, determines the default options passed to the
"   VCSDiff command.  If any options (starting with '-') are passed to the
"   command, this variable is not used.
"
" Mapping documentation: {{{2
"
"   <Leader>ce PFEdit
"   <Leader>cc PFChange
"   <Leader>cI PFIntegrate
"
" Section: Plugin header {{{1
"
" Section: TODO {{{1
"
"  [ ] Should have a way to set current cl## and then commands (like edit,
"     add, ...) will work on that cl## instead of default


if exists('VCSCommandDisableAll')
	finish
endif

if v:version < 700
	echohl WarningMsg|echomsg 'VCSCommand requires at least VIM 7.0'|echohl None
	finish
endif

runtime plugin/vcscommand.vim

if !executable(VCSCommandGetOption('VCSCommandP4Exec', 'p4'))
	" p4 is not installed
	finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Section: Variable initialization {{{1

let s:p4Functions = {}

" Section: Utility functions {{{1

" Function: s:DoCommand(cmd, cmdName, statusText, options) {{{2
" Wrapper to VCSCommandDoCommand to add the name of the p4 executable to the
" command argument.
function! s:DoCommand(cmd, cmdName, statusText, options)
	if VCSCommandGetVCSType(expand('%')) == 'p4'
		let fullCmd = VCSCommandGetOption('VCSCommandP4Exec', 'p4',) . ' ' . a:cmd
		return VCSCommandDoCommand(fullCmd, a:cmdName, a:statusText, a:options)
	else
		throw 'p4 VCSCommand plugin called on non-p4 item.'
	endif
endfunction

" Section: VCS function implementations {{{1

" Function: s:p4Functions.Identify(buffer) {{{2
" This function only returns an inexact match due to the detection method used
" by p4, which simply traverses the directory structure upward.
function! s:p4Functions.Identify(buffer)
	let oldCwd = VCSCommandChangeToCurrentFileDir(resolve(bufname(a:buffer)))
	try
		call system(VCSCommandGetOption('VCSCommandP4Exec', 'p4') . ' where')
		if(v:shell_error)
			return 0
		else
			return g:VCSCOMMAND_IDENTIFY_INEXACT
		endif
	finally
		call VCSCommandChdir(oldCwd)
	endtry
endfunction

" Function: s:p4Functions.Add(argList) {{{2
function! s:p4Functions.Add(argList)
	return s:DoCommand(join(['add'] + a:argList, ' '), 'add', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Annotate(argList) {{{2
function! s:p4Functions.Annotate(argList)
    if executable('p4Annotate')
        " This command requires the p4pl.perl script from
        " here: ftp://ftp.perforce.com/pub/perforce/contrib/misc/p4pr.perl.
        " And to be renamed to p4Annotate. Otherwise reverts to 'p4 annotate'
        " which is no fun at all.
        let options = join(a:argList, ' ')
        let resultBuffer = VCSCommandDoCommand('p4annotate' . options, '', 'annotate', {})
        if resultBuffer > 0
            normal 1G
            set filetype=p4Annotate
        endif
        return resultBuffer
    else
        return s:DoCommand(join(['annotate'] + a:argList, ' '), 'annotate', join(a:argList, ' '), {})
    endif
endfunction

" Function: s:p4Functions.Commit(argList) {{{2
function! s:p4Functions.Commit(argList)
	throw "This command is not implemented for p4."
	return s:DoCommand(join(['submit'] + a:argList, ' '), 'submit', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Delete() {{{2
" All options are passed through.
function! s:p4Functions.Delete(argList)
	return s:DoCommand(join(['delete'] + a:argList, ' '), 'delete', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Diff(argList) {{{2
" Pass-through call to p4-diff.  If no options (starting with '-') are found,
" then the options in the 'VCSCommandP4DiffOpt' variable are added.
function! s:p4Functions.Diff(argList)
	let gitDiffOpt = VCSCommandGetOption('VCSCommandGitP4Opt', '-du')
	if gitDiffOpt == ''
		let diffOptions = []
	else
		let diffOptions = [gitDiffOpt]
		for arg in a:argList
			if arg =~ '^-'
				let diffOptions = []
				break
			endif
		endfor
	endif
	let resultBuffer = s:DoCommand(join(['diff'] + diffOptions + a:argList), 'diff', join(a:argList), {})
	if resultBuffer > 0
		set filetype=diff
	else
		echomsg 'No differences found'
	endif
	return resultBuffer
endfunction

" Function: s:p4Functions.GetBufferInfo() {{{2
" Provides version control details for the current file.  Current version
" number and current repository version number are required to be returned by
" the vcscommand plugin.  This CVS extension adds branch name to the return
" list as well.
" Returns: List of results:  [revision, repository, branch]
function! s:p4Functions.GetBufferInfo()
"    if exists('b:p4Status') && b:p4Status !~# []
"        return b:p4Status
"    endif
    
	let originalBuffer = VCSCommandGetOriginalBuffer(bufnr('%'))
	let fileName = bufname(originalBuffer)

	let realFileName = fnamemodify(resolve(fileName), ':t')
	if !filereadable(fileName)
		return ['UNKNOWN']
	endif
	let oldCwd = VCSCommandChangeToCurrentFileDir(fileName)
	try
        " save and set shell redir
        let sr = &shellredir
        set shellredir=>%s\ 2>1

		let statusText1=system(VCSCommandGetOption('VCSCommandP4Exec', 'p4') . ' fstat "' . realFileName . '"')
		if(v:shell_error)
			return []
		endif
		let statusText2=system(VCSCommandGetOption('VCSCommandP4Exec', 'p4') . ' client -o')
		if(v:shell_error)
			return []
		endif
        " Restore shell redir
        let &shellredir = sr

        " Due to newline crappieness, these regex have to matche the middle of
        " a long string rather than using ^...$ 
        " TODO: They should still be clened up however.
		let revision=substitute(statusText1, '.*\.\.\.\s*haveRev\s*\(\d*\).*', '\1', '')
        if match(revision,"[0-9]*") < 0
            echo revision
            let revision="UNKNOWN"
        endif

		let branch=substitute(statusText1, '.*\.\.\.\s*change\s*\([a-zA-Z0-9]*\).*', '\1', '')
        if match(branch,"depotFile") >= 0
            let branch='UNOPENED'
        endif

		let repository=substitute(statusText2, '.*Client:\s*\([a-zA-Z0-9_-]*\).*', '\1', '')
        "let repository=''

        let b:p4Status = [revision, repository, branch]
		return [revision, repository, branch]
	finally
		call VCSCommandChdir(oldCwd)
	endtry
endfunction

function! s:p4Functions.Info(argList)
	return s:DoCommand(join(['fstat'] + a:argList, ' '), 'fstat', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Log() {{{2
function! s:p4Functions.Log(argList)
	return s:DoCommand(join(['filelog'] + a:argList, ' '), 'filelog', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Revert(argList) {{{2
function! s:p4Functions.Revert(argList)
	return s:DoCommand(join(['revert'] + a:argList, ' '), 'revert', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Review(argList) {{{2
function! s:p4Functions.Review(argList)
	if len(a:argList) == 0
		let versiontag = '(current)'
		let versionOption = ''
	else
		let versiontag = a:argList[0]
		let versionOption = '#' . versiontag . ' '
	endif
	let resultBuffer = s:DoCommand('print <VCSCOMMANDFILE>'.versionOption, 'print', versiontag, {})
	if resultBuffer > 0
		let &filetype=getbufvar(b:VCSCommandOriginalBuffer, '&filetype')
	endif
	return resultBuffer
endfunction

" Function: s:p4Functions.Status(argList) {{{2
function! s:p4Functions.Status(argList)
	return s:DoCommand(join(['fstat'] + a:argList, ' '), 'fstat', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Update(argList) {{{2
function! s:p4Functions.Update(argList)
	return s:DoCommand(join(['sync'] + a:argList, ' '), 'sync', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Lock(argList) {{{2
function! s:p4Functions.Lock(argList)
	return s:DoCommand(join(['lock'] + a:argList, ' '), 'lock', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Unlock(argList) {{{2
function! s:p4Functions.Unlock(argList)
	return s:DoCommand(join(['unlock'] + a:argList, ' '), 'unlock', join(a:argList, ' '), {})
endfunction

"VCSGotoOriginal
"VCSReview
"VCSVimDiff
"P4Edit
" Function: s:Edit(argList) {{{2
function! s:PFEdit(argList)
	let originalBuffer = VCSCommandGetOriginalBuffer(bufnr('%'))
	let fileName = bufname(originalBuffer)
	let resultBuffer = s:DoCommand(join(['edit'] + a:argList, ' ' + fileName), 'edit', join(a:argList, ' '), {})
    " set buffer for to re-get info.
    call setbufvar(originalBuffer, 'VCSCommandBufferSetup', 0)
	return resultBuffer
endfunction
"P4Change
" Function: s:Change(argList) {{{2
function! s:PFChange(argList)
	return s:DoCommand(join(['change'] + a:argList, ' '), 'change', join(a:argList, ' '), {})
endfunction
"P4Integrate
" Function: s:Change(argList) {{{2
function! s:PFIntegrate(argList)
	return s:DoCommand(join(['integrate'] + a:argList, ' '), 'integrate', join(a:argList, ' '), {})
endfunction

" Section: Command definitions {{{1
" Section: Primary commands {{{2
com! -nargs=* PFEdit call s:PFEdit([<f-args>])
com! -nargs=* PFChange call s:PFChange([<f-args>])
com! -nargs=* PFIntegrate call s:PFIntegrate([<f-args>])

" Section: Plugin command mappings {{{1

let s:p4ExtensionMappings = {}
let mappingInfo = [
			\['PFEdit', 'PFEdit', 'e'],
			\['PFChange', 'PFChange', 'c'],
			\['PFIntegrate', 'PFIntegrate', 'I'],
            \]

for [pluginName, commandText, shortCut] in mappingInfo
	execute 'nnoremap <silent> <Plug>' . pluginName . ' :' . commandText . '<CR>'
	if !hasmapto('<Plug>' . pluginName)
		let s:p4ExtensionMappings[shortCut] = commandText
	endif
endfor

" Section: Menu items {{{1
silent! aunmenu Plugin.VCS.P4
amenu <silent> &Plugin.VCS.P4.&Edit       <Plug>PFEdit
amenu <silent> &Plugin.VCS.P4.&Change       <Plug>PFChange
amenu <silent> &Plugin.VCS.P4.&Integrate       <Plug>PFIntegrate

" Stolen from other perforce script, used to cancel an edit.
function! s:CancelEdit(stage)
    "echo 'Sorry, cannot cancel edit, just undo'
    aug P4CancelEdit
        au!
        if a:stage == 0
            au CursorMovedI <buffer> nested :call <SID>CancelEdit(1)
            au CursorMoved <buffer> nested :call <SID>CancelEdit(1)
        elseif a:stage == 1
            stopinsert
            silent undo
            setl readonly
        endif
    aug END
endfunction

function! s:CheckOutFile()
    let originalBuffer = VCSCommandGetOriginalBuffer(bufnr('%'))
    let vcs_type = ""
    try
        let vcs_type = VCSCommandGetVCSType(originalBuffer)
    catch
        " nothing, couldn't find type ...
    endtry
	if vcs_type != 'p4'
        return
    endif
    if filereadable(expand("%")) && ! filewritable(expand("%"))
        let option = confirm("Readonly file, do you want to checkout from perforce?", "&Yes\n&No\n&Cancel", 2, "Question")
        if option == 1
            let fileName = bufname(originalBuffer)
            " Can't use PFEdit becaue it tries to open a buffer with results,
            " just use the system command here.
            "silent call s:PFEdit([])
            silent call system(VCSCommandGetOption('VCSCommandP4Exec', 'p4') . ' edit ' . fileName)
            " set buffer for to re-get info.
            if(v:shell_error)
                echohl WarningMsg|echomsg 'error grabbing for edit' |echohl None
                return
            else
                silent call setbufvar(originalBuffer, 'VCSCommandBufferSetup', 0)
                setlocal noreadonly
            endif
        elseif option == 3
            call s:CancelEdit(0)
        endif
    endif
endfunction

au FileChangedRO * nested :call <SID>CheckOutFile()

" Section: Plugin Registration {{{1
call VCSCommandRegisterModule('p4', expand('<sfile>'), s:p4Functions, [])

let &cpo = s:save_cpo
