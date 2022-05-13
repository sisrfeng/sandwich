" operator-sandwich: wrap by buns!
" TODO Give API to get information from operator object.
"      It would be helpful for users in use of 'expr_filter' and 'command' option.
" TODO Add 'at' option

" variables "{{{
let s:constants = function('sandwich#constants#get')

" patchs
if v:version > 704 || (v:version == 704 && has('patch237'))
    let s:has_patch_7_4_392 = has('patch-7.4.392')
el
    let s:has_patch_7_4_392 = v:version == 704 && has('patch392')
en

" Others
" NOTE: This would be updated in each operator functions (operator#sandwich#{add/delete/replce})
let s:is_in_cmdline_window = 0
" Current set operator
let s:operator = ''
"}}}
" highlight {{{
fun! s:default_highlight() abort
    hi default link OperatorSandwichBuns   IncSearch
    hi default link OperatorSandwichAdd    DiffAdd
    hi default link OperatorSandwichDelete DiffDelete

    if hlexists('OperatorSandwichStuff')
        hi default link OperatorSandwichChange OperatorSandwichStuff
    el
        " obsolete
        hi default link OperatorSandwichChange DiffChange
    en
endf
call s:default_highlight()

augroup sandwich-event-ColorScheme
    autocmd!
    autocmd ColorScheme * call s:default_highlight()
augroup END
"}}}

""" Public functions
" Prerequisite
    fun! operator#sandwich#prerequisite(kind, mode, ...) abort "{{{
            " make new operator object
            let g:operator#sandwich#object = operator#sandwich#operator#new()

            " prerequisite
            let operator = g:operator#sandwich#object
            let operator.state = 1
            let operator.kind = a:kind
            let operator.count = a:mode ==# 'x' ? max([1, v:prevcount]) : v:count1
            let operator.mode = a:mode
            let operator.view = winsaveview()
            let operator.cursor.keepable = 1
            let operator.cursor.keep[0:3] = getpos('.')[0:3]
            let operator.opt = sandwich#opt#new(a:kind, {}, get(a:000, 0, {}))
            let operator.recipes.arg = get(a:000, 1, [])
            let operator.recipes.arg_given = a:0 > 1

            let [operator.extended, operator.blockwidth] = s:blockwisevisual_info(a:mode)

            let &l:operatorfunc = 'operator#sandwich#' . a:kind
            let s:operator = a:kind
            return
        endf
    "}}}

    fun! operator#sandwich#keymap(kind, mode, ...) abort "{{{
        if a:0 == 0
            call operator#sandwich#prerequisite(a:kind, a:mode)
        elseif a:0 == 1
            call operator#sandwich#prerequisite(a:kind, a:mode, a:1)
        el
            call operator#sandwich#prerequisite(a:kind, a:mode, a:1, a:2)
        en

        let cmd = a:mode ==# 'x' ? 'gvg@' : 'g@'
        call feedkeys(cmd, 'inx')
        return
    endf
    "}}}
    fun! s:blockwisevisual_info(mode) abort  "{{{
        if a:mode ==# 'x' && visualmode() ==# "\<C-v>"
            " The case for blockwise selections in visual mode
            " NOTE: 'extended' could be recorded safely only at here. Do not move.
            let registers = s:saveregisters()
            let lazyredraw = &lazyredraw
            set lazyredraw
            let view = winsaveview()
            try
                normal! gv
                let extended = winsaveview().curswant == s:constants('colmax')
                silent noautocmd normal! ""y
                let regtype = getregtype('"')
            finally
                call winrestview(view)
                let &lazyredraw = lazyredraw
                call s:restoreregisters(registers)
            endtry
            let blockwidth = str2nr(regtype[1:])
        el
            let extended   = 0
            let blockwidth = 0
        en
        return [extended, blockwidth]
    endf
    "}}}
    fun! s:saveregisters() abort "{{{
        let registers = {}
        let registers['0'] = s:getregister('0')
        let registers['1'] = s:getregister('1')
        let registers['2'] = s:getregister('2')
        let registers['3'] = s:getregister('3')
        let registers['4'] = s:getregister('4')
        let registers['5'] = s:getregister('5')
        let registers['6'] = s:getregister('6')
        let registers['7'] = s:getregister('7')
        let registers['8'] = s:getregister('8')
        let registers['9'] = s:getregister('9')
        let registers['"'] = s:getregister('"')
        if &clipboard =~# 'unnamed'
            let registers['*'] = s:getregister('*')
        en
        if &clipboard =~# 'unnamedplus'
            let registers['+'] = s:getregister('+')
        en
        return registers
    endf
    "}}}
    fun! s:restoreregisters(registers) abort "{{{
        for [register, contains] in items(a:registers)
            call s:setregister(register, contains)
        endfor
    endf
    "}}}
    fun! s:getregister(register) abort "{{{
        return [getreg(a:register), getregtype(a:register)]
    endf
    "}}}
    fun! s:setregister(register, contains) abort "{{{
        let [value, options] = a:contains
        return setreg(a:register, value, options)
    endf
    "}}}

" Operator functions
    fun! operator#sandwich#add(motionwise, ...) abort  "{{{
        call s:do('add', a:motionwise, 'OperatorSandwichAddPre', 'OperatorSandwichAddPost')
    endf
    "}}}
    fun! operator#sandwich#delete(motionwise, ...) abort  "{{{
        call s:do('delete', a:motionwise, 'OperatorSandwichDeletePre', 'OperatorSandwichDeletePost')
    endf
    "}}}
    fun! operator#sandwich#replace(motionwise, ...) abort  "{{{
        call s:do('replace', a:motionwise, 'OperatorSandwichReplacePre', 'OperatorSandwichReplacePost')
    endf
    "}}}
    fun! s:do(kind, motionwise, AutocmdPre, AutocmdPost) abort "{{{
        let s:operator = ''
        if exists('g:operator#sandwich#object')
            let operator = g:operator#sandwich#object
            let messenger = sandwich#messenger#new()
            let defaultopt = s:default_options(a:kind, a:motionwise)
            call operator.opt.update('default', defaultopt)
            call s:update_is_in_cmdline_window()
            call s:doautocmd(a:AutocmdPre)
            call operator.execute(a:motionwise)
            call s:doautocmd(a:AutocmdPost)
            call messenger.notify('operator-sandwich: ')
        en
    endf
    "}}}
    " function! s:update_is_in_cmdline_window() abort  "{{{
    if s:has_patch_7_4_392
        fun! s:update_is_in_cmdline_window() abort
            let s:is_in_cmdline_window = getcmdwintype() !=# ''
        endf
    el
        fun! s:update_is_in_cmdline_window() abort
            let s:is_in_cmdline_window = 0
            try
                exe     'tabnext ' . tabpagenr()
            catch /^Vim\%((\a\+)\)\=:E11/
                let s:is_in_cmdline_window = 1
            catch
            endtry
        endf
    en
    "}}}
    fun! s:doautocmd(name) abort "{{{
        let view = s:saveview()
        try
            if exists('#User#' . a:name)
                exe     'doautocmd <nomodeline> User ' . a:name
            en
        catch
            let errormsg = printf('operator-sandwich: An error occurred in autocmd %s. [%s]', a:name, v:exception)
            echoerr errormsg
        finally
            call s:restview(view, a:name)
        endtry
    endf
    "}}}
    fun! s:saveview() abort  "{{{
        return [tabpagenr(), winnr(), winsaveview(), getpos("'["), getpos("']")]
    endf
    "}}}
    fun! s:restview(view, name) abort  "{{{
        let [tabpagenr, winnr, view, modhead, modtail] = a:view

        if s:is_in_cmdline_window
            " in cmdline-window
            return
        en

        " tabpage
        try
            exe     'tabnext ' . tabpagenr
            if tabpagenr() != tabpagenr
                throw 'OperatorSandwichError:CouldNotRestoreTabpage'
            en
        catch /^OperatorSandwichError:CouldNotRestoreTabpage/
            let errormsg = printf('operator-sandwich: Could not have restored tabpage after autocmd %s.', a:name)
            echoerr errormsg
        endtry

        " window
        try
            exe     winnr . 'wincmd w'
        catch /^Vim\%((\a\+)\)\=:E16/
            let errormsg = printf('operator-sandwich: Could not have restored window after autocmd %s.', a:name)
            echoerr errormsg
        endtry
        " view
        call winrestview(view)
        " marks
        call setpos("'[", modhead)
        call setpos("']", modtail)
    endf
    "}}}

" For the query1st series mappings
    fun! operator#sandwich#query1st(kind, mode, ...) abort "{{{
        if a:kind !=# 'add' && a:kind !=# 'replace'
            return
        en

        " prerequisite
        let arg_opt = get(a:000, 0, {})
        let arg_recipes = get(a:000, 1, [])
        call operator#sandwich#prerequisite(a:kind, a:mode, arg_opt, arg_recipes)
        let operator = g:operator#sandwich#object
        " NOTE: force to set highlight=0 and query_once=1
        call operator.opt.update('default', {'highlight': 0, 'query_once': 1, 'expr': 0, 'listexpr': 0})
        let operator.recipes.arg_given = a:0 > 1

        let stuff = operator#sandwich#stuff#new()
        call stuff.initialize(operator.count, operator.cursor, operator.modmark)
        let operator.basket = [stuff]

        " pick 'recipe' up and query prefered buns
        call operator.recipes.integrate(a:kind, 'all', a:mode)
        for i in range(operator.count)
            let opt = operator.opt
            let recipe = operator.query()
            let operator.recipes.dog_ear += [recipe]
            if !has_key(recipe, 'buns') || recipe.buns == []
                break
            en

            call opt.update('recipe_add', recipe)
            if i == 0 && operator.count > 1 && opt.of('query_once')
                call operator.recipes.fill(recipe, operator.count)
                break
            en
        endfor

        if filter(copy(operator.recipes.dog_ear), 'has_key(v:val, "buns")') != []
            let operator.state = 0
            let cmd = a:mode ==# 'x'
                        \ ? "\<Plug>(operator-sandwich-gv)\<Plug>(operator-sandwich-g@)"
                        \ : "\<Plug>(operator-sandwich-g@)"
            call feedkeys(cmd, 'im')
        el
            unlet g:operator#sandwich#object
        en
        return
    endf
    "}}}

" Supplementary keymappings
    fun! operator#sandwich#synchro_count() abort  "{{{
        if exists('g:operator#sandwich#object')
            return g:operator#sandwich#object.count
        el
            return ''
        en
    endf
    "}}}
    fun! operator#sandwich#release_count() abort  "{{{
        if exists('g:operator#sandwich#object')
            let l:count = g:operator#sandwich#object.count
            let g:operator#sandwich#object.count = 1
            return l:count
        el
            return ''
        en
    endf
    "}}}
    fun! operator#sandwich#squash_count() abort  "{{{
        if exists('g:operator#sandwich#object')
            let g:operator#sandwich#object.count = 1
        en
        return ''
    endf
    "}}}
    fun! operator#sandwich#predot() abort  "{{{
        if exists('g:operator#sandwich#object')
            let operator = g:operator#sandwich#object
            let operator.cursor.keepable = 1
            let operator.cursor.keep[0:3] = getpos('.')[0:3]
        en
        return ''
    endf
    "}}}
    fun! operator#sandwich#dot() abort  "{{{
        call operator#sandwich#predot()
        return '.'
    endf
    "}}}

" visualrepeat.vim (vimscript #3848) support
    fun! operator#sandwich#visualrepeat(kind) abort  "{{{
        let operator = g:operator#sandwich#object

        let original_mode = operator.mode
        let original_extended = operator.extended
        let original_blockwidth = operator.blockwidth

        let operator.mode = 'x'
        let [operator.extended, operator.blockwidth] = s:blockwisevisual_info('x')
        try
            normal! gv
            let operator.cursor.keepable = 1
            let operator.cursor.keep[0:3] = getpos('.')[0:3]

            let l:count = v:count ? v:count : ''
            let &l:operatorfunc = 'operator#sandwich#' . a:kind
            let cmd = printf("normal! %sg@", l:count)
            exe     cmd
        finally
            let operator.mode = original_mode
            let operator.extended = original_extended
            let operator.blockwidth = original_blockwidth
        endtry
    endf
    "}}}

" API
    fun! operator#sandwich#show(...) abort  "{{{
        if !exists('g:operator#sandwich#object') || !g:operator#sandwich#object.at_work
            echoerr 'operator-sandwich: Not in an operator-sandwich operation!'
            return 1
        en

        let operator = g:operator#sandwich#object
        let kind = operator.kind
        let opt  = operator.opt
        let place = get(a:000, 0, '')
        if kind ==# 'add'
            if place ==# ''
                let place = 'stuff'
            en
            if place ==# 'added'
                let hi_group = s:get_ifnotempty(a:000, 1, 'OperatorSandwichAdd')
            el
                let hi_group = opt.of('highlight') >= 2
                                        \ ? s:get_ifnotempty(a:000, 1, 'OperatorSandwichChange')
                                        \ : s:get_ifnotempty(a:000, 1, 'OperatorSandwichBuns')
            en
        elseif kind ==# 'delete'
            if place ==# ''
                let place = 'target'
            en
            let hi_group = opt.of('highlight') >= 2
                                    \ ? s:get_ifnotempty(a:000, 1, 'OperatorSandwichDelete')
                                    \ : s:get_ifnotempty(a:000, 1, 'OperatorSandwichBuns')
        elseif kind ==# 'replace'
            if place ==# ''
                let place = 'target'
            en
            if place ==# 'added'
                let hi_group = s:get_ifnotempty(a:000, 1, 'OperatorSandwichAdd')
            elseif place ==# 'target'
                let hi_group = opt.of('highlight') >= 2
                                        \ ? s:get_ifnotempty(a:000, 1, 'OperatorSandwichDelete')
                                        \ : s:get_ifnotempty(a:000, 1, 'OperatorSandwichBuns')
            el
                let hi_group = opt.of('highlight') >= 2
                                        \ ? s:get_ifnotempty(a:000, 1, 'OperatorSandwichChange')
                                        \ : s:get_ifnotempty(a:000, 1, 'OperatorSandwichBuns')
            en
        el
            return 1
        en
        let forcibly = get(a:000, 2, 0)
        return operator.show(place, hi_group, forcibly)
    endf
    "}}}
    fun! operator#sandwich#quench(...) abort  "{{{
        if exists('g:operator#sandwich#object')
            let operator = g:operator#sandwich#object
            let kind = operator.kind
            let place = get(a:000, 0, '')
            if place ==# ''
                if kind ==# 'add'
                    let place = 'stuff'
                elseif kind ==# 'delete'
                    let place = 'target'
                elseif kind ==# 'replace'
                    let place = 'target'
                el
                    return 1
                en
            en
            return operator.quench(place)
        en
    endf
    "}}}
    fun! operator#sandwich#get_info(...) abort  "{{{
        if !exists('g:operator#sandwich#object') || !g:operator#sandwich#object.at_work
            echoerr 'operator-sandwich: Not in an operator-sandwich operation!'
            return 1
        en

        let info = get(a:000, 0, '')
        if a:0 == 0 || info ==# ''
            return g:operator#sandwich#object
        elseif info ==# 'state' || info ==# 'kind' || info ==# 'count' || info ==# 'mode' || info ==# 'motionwise'
            return g:operator#sandwich#object[info]
        el
            echoerr printf('operator-sandwich: Identifier "%s" is not supported.', string(info))
            return 1
        en
    endf
    "}}}
    fun! operator#sandwich#kind() abort  "{{{
        return exists('g:operator#sandwich#object') && g:operator#sandwich#object.at_work
                    \ ? g:operator#sandwich#object.kind
                    \ : s:operator
    endf
    "}}}
    fun! s:get_ifnotempty(list, idx, default) abort "{{{
        let item = get(a:list, a:idx, '')
        if item ==# ''
            let item = a:default
        en
        return item
    endf
    "}}}

" For internal communication
    fun! operator#sandwich#is_in_cmd_window() abort  "{{{
        return s:is_in_cmdline_window
    endf
    "}}}
    fun! operator#sandwich#synchronize(kind, recipe) abort "{{{
        if exists('g:operator#sandwich#object') && !empty(a:recipe)
            let g:operator#sandwich#object.recipes.synchro.on = 1
            let g:operator#sandwich#object.recipes.synchro.kind = a:kind
            let g:operator#sandwich#object.recipes.synchro.recipe = [a:recipe]
        en
    endf
    "}}}

" recipes "{{{
    fun! operator#sandwich#get_recipes() abort   "{{{
        if exists('b:operator_sandwich_recipes')
            let recipes = b:operator_sandwich_recipes
        elseif exists('g:operator#sandwich#recipes')
            let recipes = g:operator#sandwich#recipes
        el
            let recipes = g:operator#sandwich#default_recipes
        en
        return deepcopy(recipes)
    endf
    "}}}
    if exists('g:operator#sandwich#default_recipes')
        unlockvar! g:operator#sandwich#default_recipes
    en
    let g:operator#sandwich#default_recipes = []
    lockvar! g:operator#sandwich#default_recipes
    "}}}

" options "{{{
    let [s:get_operator_option] = operator#sandwich#lib#funcref(['get_operator_option'])
    fun! s:default_options(kind, motionwise) abort "{{{
        return get(b:, 'operator_sandwich_options', g:operator#sandwich#options)[a:kind][a:motionwise]
    endf
    "}}}
    fun! s:initialize_options(...) abort  "{{{
        let manner = a:0 ? a:1 : 'keep'
        let g:operator#sandwich#options = s:get_operator_option('options', {})
        for kind in ['add', 'delete', 'replace']
            if !has_key(g:operator#sandwich#options, kind)
                    let g:operator#sandwich#options[kind] = {}
            en
            for motionwise in ['char', 'line', 'block']
                if !has_key(g:operator#sandwich#options[kind], motionwise)
                        let g:operator#sandwich#options[kind][motionwise] = {}
                en
                call extend(g:operator#sandwich#options[kind][motionwise],
                                     \ sandwich#opt#defaults(kind, motionwise),
                                     \ manner)
            endfor
        endfor
    endf
    call s:initialize_options()
    "}}}
    fun! operator#sandwich#set_default() abort "{{{
        call s:initialize_options('force')
    endf
    "}}}
    fun! operator#sandwich#set(kind, motionwise, option, value) abort  "{{{
        if s:argument_error(a:kind, a:motionwise, a:option, a:value)
            return
        en

        if a:kind ==# 'all'
            let kinds = ['add', 'delete', 'replace']
        el
            let kinds = [a:kind]
        en

        if a:motionwise ==# 'all'
            let motionwises = ['char', 'line', 'block']
        el
            let motionwises = [a:motionwise]
        en

        call s:set_option_value(g:operator#sandwich#options, kinds, motionwises, a:option, a:value)
    endf
    "}}}
    fun! operator#sandwich#setlocal(kind, motionwise, option, value) abort  "{{{
        if s:argument_error(a:kind, a:motionwise, a:option, a:value)
            return
        en

        if !exists('b:operator_sandwich_options')
            let b:operator_sandwich_options = deepcopy(g:operator#sandwich#options)
        en

        if a:kind ==# 'all'
            let kinds = ['add', 'delete', 'replace']
        el
            let kinds = [a:kind]
        en

        if a:motionwise ==# 'all'
            let motionwises = ['char', 'line', 'block']
        el
            let motionwises = [a:motionwise]
        en

        call s:set_option_value(b:operator_sandwich_options, kinds, motionwises, a:option, a:value)
    endf
    "}}}
    fun! s:argument_error(kind, motionwise, option, value) abort "{{{
        if !(a:kind ==# 'add' || a:kind ==# 'delete' || a:kind ==# 'replace' || a:kind ==# 'all')
            echohl WarningMsg
            echomsg 'Invalid kind "' . a:kind . '".'
            echohl NONE
            return 1
        en

        if !(a:motionwise ==# 'char' || a:motionwise ==# 'line' || a:motionwise ==# 'block' || a:motionwise ==# 'all')
            echohl WarningMsg
            echomsg 'Invalid motion-wise "' . a:motionwise . '".'
            echohl NONE
            return 1
        en

        if a:kind !=# 'all' && a:motionwise !=# 'all'
            let defaults = sandwich#opt#defaults(a:kind, a:motionwise)
            if filter(keys(defaults), 'v:val ==# a:option') == []
                echohl WarningMsg
                echomsg 'Invalid option name "' . a:option . '".'
                echohl NONE
                return 1
            en

            if a:option !~# 'indentkeys[-+]\?' && type(a:value) != type(defaults[a:option])
                echohl WarningMsg
                echomsg 'Invalid type of value. ' . string(a:value)
                echohl NONE
                return 1
            en
        en
        return 0
    endf
    "}}}
    fun! s:set_option_value(dest, kinds, motionwises, option, value) abort  "{{{
        for kind in a:kinds
            for motionwise in a:motionwises
                let defaults = sandwich#opt#defaults(kind, motionwise)
                if filter(keys(defaults), 'v:val ==# a:option') != []
                    if a:option =~# 'indentkeys[-+]\?' || type(a:value) == type(defaults[a:option])
                        let a:dest[kind][motionwise][a:option] = a:value
                    en
                en
            endfor
        endfor
    endf
    "}}}
    "}}}

    unlet! g:operator#sandwich#object


" vim:set foldmethod=marker:
" vim:set commentstring="%s:
