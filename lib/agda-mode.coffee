Core = require './core'
{log, warn, error} = require './logger'
{$} = require 'atom-space-pen-views'

module.exports =

    configDefaults:
        executablePath: ''
        libraryPath: ''
        logLevel: 0


    activate: (state) ->
        atom.workspace.observeTextEditors @instantiateCore
        @registerEditorActivation()
        @registerCommands()


    instantiateCore: (editor) =>

        instantiate = =>
            if isAgdaFile editor
                editor.core = new Core editor
                ev = editor.onDidDestroy =>
                    editor.core.emit 'destroy'
                    ev.dispose()
            else if editor.core
                editor.core.emit 'destroy'
        instantiate()
        editor.onDidChangePath => instantiate()

    # editor active/inactive event register, fuck Atom's event clusterfuck
    registerEditorActivation: ->
        currentEditor = atom.workspace.getActivePaneItem()
        atom.workspace.onDidChangeActivePaneItem (nextEditor) =>
            current = currentEditor?.getPath?()
            next = nextEditor?.getPath?()
            if next isnt current
                currentEditor?.core?.emit 'deactivate'
                nextEditor?.core?.emit 'activate'
                currentEditor = nextEditor
                log 'Editor', "#{current} => #{next}"


    commands: [
        'agda-mode:load'
        'agda-mode:quit'
        'agda-mode:restart'
        'agda-mode:next-goal'
        'agda-mode:previous-goal'
        'agda-mode:give'
        'agda-mode:goal-type'
        'agda-mode:context'
        'agda-mode:goal-type-and-context'
        'agda-mode:goal-type-and-inferred-type'
        'agda-mode:refine'
        'agda-mode:case'
        'agda-mode:auto'
        'agda-mode:normalize'
        'agda-mode:input-symbol'
    ]


    # register keymap bindings and emit commands
    registerCommands: ->
        @commands.forEach (command) =>
            atom.commands.add 'atom-text-editor[data-grammar="source agda"]', command, =>
                if isAgdaFile()
                    editor = atom.workspace.getActivePaneItem()
                    editor.core[toCamalCase command]()


# if end with ".agda"
isAgdaFile = (editor) ->
    if editor
        filePath = editor.getPath?()
    else
        filePath = atom.workspace.getActivePaneItem().getPath()
    /\.agda$/.test filePath

toCamalCase = (str) ->
    str
        .substr(10)   # strip "agda-mode:"
        .split('-')
        .map (str, i) =>
            if i is 0
                str
            else
                str.charAt(0).toUpperCase() + str.slice(1)
        .join('')
