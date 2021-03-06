{CompositeDisposable, Range} = require 'atom'
Keymap = require './input-method/keymap'

# Input Method Singleton (initialized only once per editor, activaed or not)
class InputMethod

    activated: false
    mute: false

    subscriptions: null
    # raw characters
    rawInput: ''
    # visual marker
    textBufferMarker: null

    constructor: (@core) ->

        # intercept newline `\n` as confirm
        commands =
            'editor:newline': (ev) =>
                if @activated
                    @deactivate()
                    ev.stopImmediatePropagation()

        @subscriptions = new CompositeDisposable
        @subscriptions.add atom.commands.add 'atom-text-editor.agda-mode-input-method-activated', commands

    destroy: ->
        @subscriptions.destroy()

    activate: ->
        if not @activated

            # initializations
            @rawInput = ''
            @activated = true


            # add class 'agda-mode-input-method-activated'
            editorElement = atom.views.getView(atom.workspace.getActiveTextEditor())
            editorElement.classList.add 'agda-mode-input-method-activated'

            # editor: the main text editor or the mini text editor
            inputEditorFocused = @core.panel.$refs.inputEditor.isFocused()
            @editor = if inputEditorFocused then @core.panel.$refs.inputEditor.$el.getModel() else @core.editor

            # monitors raw text buffer and figures out what happend
            startPosition = @editor.getCursorBufferPosition()
            @textBufferMarker = @editor.markBufferRange(new Range startPosition, startPosition)
            @textBufferMarker.onDidChange @dispatchEvent

            # decoration
            @decoration = @editor.decorateMarker @textBufferMarker,
                type: 'highlight'
                class: 'agda-input-method'

            # insert '\' at the cursor quitely without triggering any shit
            @muteEvent =>
                @insertChar '\\'

            # initialize input suggestion
            @core.panel.inputMethodMode = true
            @core.panel.inputMethod =
                rawInput: ''
                suggestionKeys: Keymap.getSuggestionKeys(Keymap.trie).sort()
                candidateSymbols: []

        else
            # input method already activated
            # this will happen when the 2nd backslash '\' got punched in
            # we shall leave 1 backslash in the buffer, then deactivate
            @deactivate()

    deactivate: ->

        if @activated

            # add class 'agda-mode-input-method-activated'
            editorElement = atom.views.getView(atom.workspace.getActiveTextEditor())
            editorElement.classList.remove 'agda-mode-input-method-activated'

            @core.panel.inputMethodMode = false
            @textBufferMarker.destroy()
            @decoration.destroy()
            @activated = false

    ##################
    ###   Events   ###
    ##################

    muteEvent: (callback) ->
        @mute = true
        callback()
        @mute = false

    dispatchEvent: (ev) =>

        unless @mute

            rangeOld = new Range ev.oldTailBufferPosition, ev.oldHeadBufferPosition
            rangeNew = new Range ev.newTailBufferPosition, ev.newHeadBufferPosition
            textBuffer = @editor.getBuffer().getTextInRange rangeNew
            char = textBuffer.substr -1

            # const for result of Range::compare()
            INSERT = -1
            DELETE = 1
            change = rangeNew.compare rangeOld


            if rangeNew.isEmpty()
                @deactivate()
            else if change is INSERT
                char = textBuffer.substr -1
                @rawInput += char
                {translation, further, suggestionKeys, candidateSymbols} = Keymap.translate @rawInput

                # reflects current translation to the text buffer
                if translation
                    @muteEvent => @replaceString translation

                # update view
                if further
                    @core.panel.inputMethod =
                        rawInput: @rawInput
                        suggestionKeys: suggestionKeys
                        candidateSymbols: candidateSymbols
                else
                    @deactivate()

            else if change is DELETE
                @rawInput = @rawInput.substr(0, @rawInput.length - 1)
                {translation, further, suggestionKeys, candidateSymbols} = Keymap.translate @rawInput
                @core.panel.inputMethod =
                    rawInput: @rawInput
                    suggestionKeys: suggestionKeys
                    candidateSymbols: candidateSymbols


    #######################
    ###   Text Buffer   ###
    #######################

    # inserts 1 character to the text buffer (may trigger some events)
    insertChar: (char) ->
        @editor.getBuffer().insert @textBufferMarker.getBufferRange().end, char

    # inserts 1 symbol to the text buffer and deactivate
    insertSymbol: (symbol) ->
        @replaceString symbol
        @deactivate()

    # replace content of the marker with supplied string (may trigger some events)
    replaceString: (str) ->
        @editor.getBuffer().setTextInRange @textBufferMarker.getBufferRange(), str

module.exports = InputMethod
