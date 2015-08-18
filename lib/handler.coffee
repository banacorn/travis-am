_ = require 'lodash'
{OutOfGoalError} = require './error'
{log, warn, error} = require './logger'


# Handles all events coming from Agda
class Handler
    constructor: (@core) ->
        # alias
        @panel      = @core.panel
        @textBuffer = @core.textBuffer
        @highlight  = @core.highlight

    # agda2-info-action
    infoAction: (tokens) ->
        log 'Handler', 'agda2-info-action'
        # with content: ["agda2-info-action", "*Type-checking*", "Checking ...", "t"]
        # w/o  content:  ["agda2-info-action", "*Type-checking*", "nil"]
        type = tokens[1]
        content = if tokens.length is 3 then [] else _.compact tokens[2].split '\\n'

        switch type
            when '*All Goals*'
                if content.length > 0
                    @panel.setContent 'Goals', content, 'info'
                else
                    @panel.setContent 'No Goals', [], 'success'
            when '*Error*'
                @panel.setContent 'Error', content, 'error'
            when '*Type-checking*'
                @panel.setContent 'Type Checking', content
            when '*Current Goal*'
                @panel.setContent 'Current Goal', content
            when '*Inferred Type*'
                @panel.setContent 'Inferred Type', content
            when '*Module contents*'
                @panel.setContent 'Module Contents', content
            when '*Context*'
                @panel.setContent 'Context', content
            when '*Goal type etc.*'
                @panel.setContent 'Goal Type and Context', content
            when '*Normal Form*'
                @panel.setContent 'Normal Form', content
            when '*Intro*'
                @panel.setContent 'Intro', ['No introduction forms found']
            when '*Auto*'
                @panel.setContent 'Auto', ['No solution found']
            when '*Constraints*'
                @panel.setContent 'Constraints', content
            when '*Scope Info*'
                @panel.setContent 'Scope Info', content

    # agda2-status-action
    statusAction: (tokens) ->
        log 'Handler', 'agda2-status-action'
        if tokens.length isnt 1
            @panel.setContent 'Status', [tokens[1]], 'info'

    # agda2-goals-action
    goalsAction: (tokens) ->
        log 'Handler', 'agda2-goals-action'
        @textBuffer.onGoalsAction tokens[1]

    # agda2-goto
    goto: (tokens) ->
        log 'Handler', 'agda2-goto'
        filepath = tokens[1][0]
        position = tokens[1][2]
        @textBuffer.onGoto filepath, position
        @textBuffer.getCurrentGoal()
            .then (goal) => goal.selectContent()
            .catch OutOfGoalError
    # agda2-give-action
    giveAction: (tokens) ->
        log 'Handler', 'agda2-give-action'
        # with parenthesis: ["agda2-give-action", 1, "'paren"]
        # w/o  parenthesis: ["agda2-give-action", 1, "'no-paren"]
        # with content    : ["agda2-give-action", 0, ...]
        switch tokens[2]
            when "'paren"    then @textBuffer.onGiveAction tokens[1], [], true
            when "'no-paren" then @textBuffer.onGiveAction tokens[1], [], false
            else                  @textBuffer.onGiveAction tokens[1], tokens[2], false

    # agda2-make-case-action
    makeCaseAction: (tokens) ->
        log 'Handler', 'agda2-make-case-action'
        @textBuffer.onMakeCaseAction tokens[1]
            .then => @core.commander.load()

    # agda2-highlight-clear
    highlightClear: (tokens) ->
        log 'Handler', 'agda2-highlight-clear'

    # agda2-highlight-add-annotations
    highlightAddAnnotations: (tokens) ->
        log 'Handler', 'agda2-highlight-add-annotations'
        annotations = _.rest(tokens)
        annotations.forEach (obj) =>
            result =
                start: obj[0]
                end: obj[1]
                type: obj[2]
            if obj[4]
                result.source =
                    path: obj[4][0]
                    index: obj[4][2]

            result.type.forEach (type) =>
                switch type
                    when 'unsolvedmeta', 'terminationproblem'
                        @highlight.highlight result

    # agda2-highlight-load-and-delete-action
    highlightLoadAndDeleteAction: (tokens) ->
        log 'Handler', 'agda2-highlight-load-and-delete-action'
        @textBuffer.onHighlightLoadAndDelete tokens[1]

    # agda2-parse-error
    parseError: (tokens) ->
        error 'Executable', JSON.stringify tokens

module.exports = Handler
