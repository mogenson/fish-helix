# IMPORTANT!!!
#
# When defining your own bindings using fish_helix_command, be aware that it can break
# stuff sometimes.
#
# It is safe to define a binding consisting of a lone call to fish_helix_command.
# Calls to other functions and executables are allowed along with it, granted they don't mess
# with fish's commandline buffer.
#
# Mixing multiple fish_helix_commandline and commandline calls in one binding MAY trigger issues.
# Nothing serious, but don't be surprised. Just test it.

function fish_helix_key_bindings --description 'helix-like key bindings for fish'
    if contains -- -h $argv
        or contains -- --help $argv
        echo "Sorry but this function doesn't support -h or --help"
        return 1
    end

    # Erase all bindings if not explicitly requested otherwise to
    # allow for hybrid bindings.
    # This needs to be checked here because if we are called again
    # via the variable handler the argument will be gone.
    set -l rebind true
    if test "$argv[1]" = --no-erase
        set rebind false
        set -e argv[1]
    else
        bind --erase --all --preset # clear earlier bindings, if any
    end

    # Allow just calling this function to correctly set the bindings.
    # Because it's a rather discoverable name, users will execute it
    # and without this would then have subtly broken bindings.
    if test "$fish_key_bindings" != fish_helix_key_bindings
        and test "$rebind" = true
        # Allow the user to set the variable universally.
        set -q fish_key_bindings
        or set -g fish_key_bindings
        # This triggers the handler, which calls us again and ensures the user_key_bindings
        # are executed.
        set fish_key_bindings fish_helix_key_bindings
        return
    end

    set -l init_mode insert

    if contains -- $argv[1] insert default visual
        set init_mode $argv[1]
    else if set -q argv[1]
        # We should still go on so the bindings still get set.
        echo "Unknown argument $argv" >&2
    end

    # Inherit shared key bindings.
    # Do this first so helix-bindings win over default.
    for mode in insert default visual
        __fish_shared_key_bindings -s -M $mode
    end

    bind -s --preset -M insert enter execute

    bind -s --preset -M insert "" self-insert

    # Space and other command terminators expand abbrs _and_ inserts itself.
    bind -s --preset -M insert " " self-insert expand-abbr
    bind -s --preset -M insert ";" self-insert expand-abbr
    bind -s --preset -M insert "|" self-insert expand-abbr
    bind -s --preset -M insert "&" self-insert expand-abbr
    bind -s --preset -M insert "^" self-insert expand-abbr
    bind -s --preset -M insert ">" self-insert expand-abbr
    bind -s --preset -M insert "<" self-insert expand-abbr
    # Closing a command substitution expands abbreviations
    bind -s --preset -M insert ")" self-insert expand-abbr
    # Ctrl-space inserts space without expanding abbrs
    bind -s --preset -M insert ctrl-space 'commandline -i " "'

    # Switching to insert mode
    for mode in default visual
        bind -s --preset -M $mode -m insert \cc end-selection cancel-commandline repaint-mode
        bind -s --preset -M $mode -m insert enter end-selection execute
        bind -s --preset -M $mode -m insert o end-selection insert-line-under repaint-mode
        bind -s --preset -M $mode -m insert O end-selection insert-line-over repaint-mode
        # FIXME i/a should keep selection, maybe
        bind -s --preset -M $mode i "fish_helix_command insert_mode"
        bind -s --preset -M $mode I "fish_helix_command prepend_to_line"
        bind -s --preset -M $mode a "fish_helix_command append_mode"
        bind -s --preset -M $mode A "fish_helix_command append_to_line"
    end

    # Switching from insert mode
    # Note if we are paging, we want to stay in insert mode
    # See #2871
    bind -s --preset -M insert escape "if commandline -P; commandline -f cancel; else; set fish_bind_mode default; commandline -f begin-selection repaint-mode; end"

    # Switching between normal and visual mode
    bind -s --preset -M default -m visual v repaint-mode
    bind -s --preset -M visual -m default v repaint-mode
    bind -s --preset -M visual -m default escape repaint-mode


    # Motion and actions in normal/select mode
    for mode in default visual
        if test $mode = default
            set -f n_begin_selection "begin-selection" # only begin-selection if current mode is Normal
            set -f ns_move_extend "move"
            set -f commandline_v_repaint ""
        else
            set -f n_begin_selection
            set -f ns_move_extend "extend"
            set -f commandline_v_repaint "commandline -f repaint-mode"
        end

        for key in (seq 0 9)
            bind -s --preset -M $mode $key "fish_bind_count $key"
            # FIXME example to bind 0
            # FIXME backspace to edit count
        end
        # Simplified arrow key bindings
        set -l left_cmd "fish_helix_command "$ns_move_extend"_char_left"
        bind -s --preset -M $mode h $left_cmd
        bind -s --preset -M $mode left $left_cmd

        set -l right_cmd "fish_helix_command "$ns_move_extend"_char_right"
        bind -s --preset -M $mode l $right_cmd
        bind -s --preset -M $mode right $right_cmd

        bind -s --preset -M $mode k "fish_helix_command char_up"
        bind -s --preset -M $mode up "fish_helix_command char_up"

        bind -s --preset -M $mode j "fish_helix_command char_down"
        bind -s --preset -M $mode down "fish_helix_command char_down"

        bind -s --preset -M $mode w "fish_helix_command next_word_start"
        bind -s --preset -M $mode b "fish_helix_command prev_word_start"
        bind -s --preset -M $mode e "fish_helix_command next_word_end"
        bind -s --preset -M $mode W "fish_helix_command next_long_word_start"
        bind -s --preset -M $mode B "fish_helix_command prev_long_word_start"
        bind -s --preset -M $mode E "fish_helix_command next_long_word_end"

        # Character finding commands - direct binding to fish's built-in jump commands
        # t - till: move cursor right before the next occurrence of a character
        bind -s --preset -M $mode t forward-jump-till
        # f - find: move cursor to the next occurrence of a character
        bind -s --preset -M $mode f forward-jump
        # T - till reverse: move cursor right after the previous occurrence of a character
        bind -s --preset -M $mode T backward-jump-till
        # F - find reverse: move cursor to the previous occurrence of a character
        bind -s --preset -M $mode F backward-jump
        # Repeat the last find/till in same/opposite direction
        bind -s --preset -M $mode ";" repeat-jump
        bind -s --preset -M $mode "," repeat-jump-reverse

        # Bindings for newline navigation will be implemented as regular bindings
        # t + enter: move to the position right before the next newline
        bind -s --preset -M $mode "t,enter" "commandline -f forward-jump-till -- \\n"
        # f + enter: move to the next newline
        bind -s --preset -M $mode "f,enter" "commandline -f forward-jump -- \\n"
        # T + enter: move to the position right after the previous newline
        bind -s --preset -M $mode "T,enter" "commandline -f backward-jump-till -- \\n"
        # F + enter: move to the previous newline
        bind -s --preset -M $mode "F,enter" "commandline -f backward-jump -- \\n"

        # Home and end key bindings
        bind -s --preset -M $mode gh "fish_helix_command goto_line_start"
        bind -s --preset -M $mode home "fish_helix_command goto_line_start"

        bind -s --preset -M $mode gl "fish_helix_command goto_line_end"
        bind -s --preset -M $mode end "fish_helix_command goto_line_end"
        bind -s --preset -M $mode gs "fish_helix_command goto_first_nonwhitespace"
        bind -s --preset -M $mode gg "fish_helix_command goto_file_start"
        bind -s --preset -M $mode G "fish_helix_command goto_line"
        bind -s --preset -M $mode ge "fish_helix_command goto_last_line"

        # FIXME alt-. doesn't work with t/T
        # FIXME alt-. doesn't work with [ftFT][enter]
        bind -s --preset -M $mode "alt-." repeat-jump

        # FIXME reselect after undo/redo
        bind -s --preset -M $mode u undo begin-selection
        bind -s --preset -M $mode U redo begin-selection

        bind -s --preset -M $mode -m replace_one r repaint-mode

        # FIXME registers
        # bind -s --preset -M $mode y fish_clipboard_copy
        # bind -s --preset -M $mode P fish_clipboard_paste
        # bind -s --preset -M $mode R kill-selection begin-selection yank-pop yank

        if test -n "$commandline_v_repaint"
            bind -s --preset -M $mode -m default d "fish_helix_command delete_selection; commandline -f repaint-mode"
            bind -s --preset -M $mode -m default "alt-d" "fish_helix_command delete_selection_noyank; commandline -f repaint-mode"
        else
            bind -s --preset -M $mode -m default d "fish_helix_command delete_selection"
            bind -s --preset -M $mode -m default "alt-d" "fish_helix_command delete_selection_noyank"
        end
        bind -s --preset -M $mode -m insert c "fish_helix_command delete_selection; commandline -f end-selection repaint-mode"
        bind -s --preset -M $mode -m insert "alt-c" "fish_helix_command delete_selection_noyank; commandline -f end-selection repaint-mode"

        bind -s --preset -M $mode -m default y "fish_helix_command yank"
        bind -s --preset -M $mode p "fish_helix_command paste_after"
        bind -s --preset -M $mode P "fish_helix_command paste_before"
        bind -s --preset -M $mode R "fish_helix_command replace_selection"

        if test -n "$commandline_v_repaint"
            bind -s --preset -M $mode -m default " y" "fish_clipboard_copy; commandline -f repaint-mode"
        else
            bind -s --preset -M $mode -m default " y" "fish_clipboard_copy"
        end
        bind -s --preset -M $mode " p" "fish_helix_command paste_after_clip"
        bind -s --preset -M $mode " P" "fish_helix_command paste_before_clip"
        bind -s --preset -M $mode " R" "fish_helix_command replace_selection_clip"

        # FIXME keep selection
        bind -s --preset -M $mode ~ togglecase-selection
        # FIXME ` and escape,`

        # FIXME .
        # FIXME < and >
        # FIXME =

        # FIXME ctrl-a ctrl-x
        # FIXME Qq

        ## Shell
        # FIXME

        ## Selection manipulation
        # FIXME & _

        bind -s --preset -M $mode \; begin-selection
        bind -s --preset -M $mode "escape,;" swap-selection-start-stop
        # FIXME escape:

        bind -s --preset -M $mode % "fish_helix_command select_all"
        bind -s --preset -M $mode x "fish_helix_command select_line"

        # FIXME X alt-x
        # FIXME J
        # FIXME ctrl-c

        ## Search
        # FIXME

        ## FIXME minor modes: g, m, space

        ## FIXME [ and ] motions
    end

    # FIXME should replace the whole selection
    # FIXME should be able to go back to visual mode
    bind -s --preset -M replace_one -m default '' delete-char self-insert backward-char repaint-mode
    bind -s --preset -M replace_one -m default enter 'commandline -f delete-char; commandline -i \n; commandline -f backward-char; commandline -f repaint-mode'
    bind -s --preset -M replace_one -m default escape cancel repaint-mode


    ## FIXME Insert mode keys

    ## Old config from vi:

    # Vi moves the cursor back if, after deleting, it is at EOL.
    # To emulate that, move forward, then backward, which will be a NOP
    # if there is something to move forward to.
    bind -s --preset -M insert delete delete-char forward-single-char backward-char
    bind -s --preset -M default delete delete-char forward-single-char backward-char

    # Backspace deletes a char in insert mode, but not in normal/default mode.
    bind -s --preset -M insert backspace backward-delete-char
    bind -s --preset -M default backspace backward-char
    bind -s --preset -M insert \ch backward-delete-char
    bind -s --preset -M default \ch backward-char
    bind -s --preset -M insert \x7f backward-delete-char
    bind -s --preset -M default \x7f backward-char
    bind -s --preset -M insert shift-delete backward-delete-char # shifted delete
    bind -s --preset -M default shift-delete backward-delete-char # shifted delete


#    bind -s --preset '~' togglecase-char forward-single-char
#    bind -s --preset gu downcase-word
#    bind -s --preset gU upcase-word
#
#    bind -s --preset J end-of-line delete-char
#    bind -s --preset K 'man (commandline -t) 2>/dev/null; or echo -n \a'
#



    # same vim 'pasting' note as upper
    bind -s --preset '"*p' forward-char "commandline -i ( xsel -p; echo )[1]"
    bind -s --preset '"*P' "commandline -i ( xsel -p; echo )[1]"



    #
    # visual mode
    #



    # bind -s --preset -M visual -m insert c kill-selection end-selection repaint-mode
    # bind -s --preset -M visual -m insert s kill-selection end-selection repaint-mode
    bind -s --preset -M visual -m default '"*y' "fish_clipboard_copy; commandline -f end-selection repaint-mode"
    bind -s --preset -M visual -m default '~' togglecase-selection end-selection repaint-mode



    # Set the cursor shape
    # After executing once, this will have defined functions listening for the variable.
    # Therefore it needs to be before setting fish_bind_mode.
    fish_vi_cursor

    # Configure specific cursor shapes for each mode
    set -g fish_cursor_default block      # Normal mode: block
    set -g fish_cursor_insert line        # Insert mode: line
    set -g fish_cursor_replace_one underscore
    set -g fish_cursor_replace underscore
    set -g fish_cursor_visual underscore  # Visual mode: underscore

    set -g fish_cursor_selection_mode inclusive

    set fish_bind_mode $init_mode

end
