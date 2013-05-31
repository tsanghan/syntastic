if exists("g:loaded_syntastic_registry")
    finish
endif
let g:loaded_syntastic_registry = 1

let s:defaultCheckers = {
        \ 'c':          ['gcc'],
        \ 'coffee':     ['coffee', 'coffeelint'],
        \ 'cpp':        ['gcc'],
        \ 'css':        ['csslint', 'phpcs'],
        \ 'go':         ['go'],
        \ 'html':       ['tidy'],
        \ 'java':       ['javac'],
        \ 'javascript': ['jshint', 'jslint'],
        \ 'json':       ['jsonlint', 'jsonval'],
        \ 'objc':       ['gcc'],
        \ 'objcpp':     ['gcc'],
        \ 'perl':       ['perl', 'perlcritic'],
        \ 'php':        ['php', 'phpcs', 'phpmd'],
        \ 'python':     ['python', 'flake8', 'pylint'],
        \ 'ruby':       ['mri'],
        \ 'sh':         ['sh'],
        \ 'tex':        ['lacheck']
    \ }

let g:SyntasticRegistry = {}

" TODO: Handling of filetype aliases: all public methods take aliases as
" parameters, all private methods take normalized filetypes.  Public methods
" are thus supposed to normalize filetypes before calling private methods.

" Public methods {{{1

function! g:SyntasticRegistry.Instance()
    if !exists('s:SyntasticRegistryInstance')
        let s:SyntasticRegistryInstance = copy(self)
        let s:SyntasticRegistryInstance._checkerMap = {}
    endif

    return s:SyntasticRegistryInstance
endfunction

function! g:SyntasticRegistry.CreateAndRegisterChecker(args)
    let checker = g:SyntasticChecker.New(a:args)
    let registry = g:SyntasticRegistry.Instance()
    call registry.registerChecker(checker)
endfunction

function! g:SyntasticRegistry.registerChecker(checker) abort
    let ft = a:checker.filetype()

    if !has_key(self._checkerMap, ft)
        let self._checkerMap[ft] = []
    endif

    call self._validateUniqueName(a:checker)

    call add(self._checkerMap[ft], a:checker)
endfunction

function! g:SyntasticRegistry.checkable(ftalias)
    return !empty(self.getActiveCheckers(a:ftalias))
endfunction

function! g:SyntasticRegistry.getActiveCheckers(ftalias)
    let filetype = SyntasticNormalizeFiletype(a:ftalias)
    let checkers = self.availableCheckersFor(filetype)

    if self._userHasFiletypeSettings(filetype)
        return self._filterCheckersByUserSettings(checkers, filetype)
    endif

    if has_key(s:defaultCheckers, filetype)
        return self._filterCheckersByDefaultSettings(checkers, filetype)
    endif

    let checkers = self.availableCheckersFor(filetype)

    if !empty(checkers)
        return [checkers[0]]
    endif

    return []
endfunction

function! g:SyntasticRegistry.getChecker(ftalias, name)
    for checker in self.availableCheckersFor(a:ftalias)
        if checker.name() == a:name
            return checker
        endif
    endfor

    return {}
endfunction

function! g:SyntasticRegistry.availableCheckersFor(ftalias)
    let filetype = SyntasticNormalizeFiletype(a:ftalias)
    let checkers = copy(self._allCheckersFor(filetype))
    return self._filterCheckersByAvailability(checkers)
endfunction

function! g:SyntasticRegistry.echoInfoFor(ftalias_list)
    echomsg "Syntastic info for filetype: " . join(a:ftalias_list, '.')

    let available = []
    let active = []
    for ftalias in a:ftalias_list
        call extend(available, self.availableCheckersFor(ftalias))
        call extend(active, self.getActiveCheckers(ftalias))
    endfor

    echomsg "Available checkers: " . join(syntastic#util#unique(map(available, "v:val.name()")))
    echomsg "Currently active checker(s): " . join(syntastic#util#unique(map(active, "v:val.name()")))
endfunction

" Private methods {{{1

function! g:SyntasticRegistry._allCheckersFor(filetype)
    call self._loadCheckers(a:filetype)
    if empty(self._checkerMap[a:filetype])
        return []
    endif

    return self._checkerMap[a:filetype]
endfunction

function! g:SyntasticRegistry._filterCheckersByDefaultSettings(checkers, filetype)
    if has_key(s:defaultCheckers, a:filetype)
        let whitelist = s:defaultCheckers[a:filetype]
        return filter(a:checkers, "index(whitelist, v:val.name()) != -1")
    endif

    return a:checkers
endfunction

function! g:SyntasticRegistry._filterCheckersByUserSettings(checkers, filetype)
    if exists("b:syntastic_checkers")
        let whitelist = b:syntastic_checkers
    else
        let whitelist = g:syntastic_{a:filetype}_checkers
    endif
    return filter(a:checkers, "index(whitelist, v:val.name()) != -1")
endfunction

function! g:SyntasticRegistry._filterCheckersByAvailability(checkers)
    return filter(a:checkers, "v:val.isAvailable()")
endfunction

function! g:SyntasticRegistry._loadCheckers(filetype)
    if self._haveLoadedCheckers(a:filetype)
        return
    endif

    exec "runtime! syntax_checkers/" . a:filetype . "/*.vim"

    if !has_key(self._checkerMap, a:filetype)
        let self._checkerMap[a:filetype] = []
    endif
endfunction

function! g:SyntasticRegistry._haveLoadedCheckers(filetype)
    return has_key(self._checkerMap, a:filetype)
endfunction

function! g:SyntasticRegistry._userHasFiletypeSettings(filetype)
    if exists("g:syntastic_" . a:filetype . "_checker") && !exists("g:syntastic_" . a:filetype . "_checkers")
        let g:syntastic_{a:filetype}_checkers = [g:syntastic_{a:filetype}_checker]
        call syntastic#util#deprecationWarn("variable g:syntastic_" . a:filetype . "_checker is deprecated")
    endif
    return exists("b:syntastic_checkers") || exists("g:syntastic_" . a:filetype . "_checkers")
endfunction

function! g:SyntasticRegistry._validateUniqueName(checker) abort
    for checker in self._allCheckersFor(a:checker.filetype())
        if checker.name() == a:checker.name()
            throw "Syntastic: Duplicate syntax checker name for: " . a:checker.name()
        endif
    endfor
endfunction

" vim: set sw=4 sts=4 et fdm=marker:
