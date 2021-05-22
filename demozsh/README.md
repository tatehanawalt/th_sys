# demozsh
Demozsh is a demo cli written in zsh intended to demonstrate interesting features / usage examples of zsh and provide some system utilities to the installers environment.

## Tips for developing stable zsh scripts:

Set up the ability to enable a strict dev mode. Some useful options for this are:

**ERR_EXIT:**
```
If a command has a non-zero exit status, execute the ZERR trap, if set, and exit. This is disabled while running initialization scripts.

The behaviour is also disabled inside DEBUG traps. In this case the option is handled specially: it is unset on entry to the trap. If the option DEBUG_BEFORE_CMD is set, as it is by default, and the option ERR_EXIT is found to have been set on exit, then the command for which the DEBUG trap is being executed is skipped. The option is restored after the trap exits.

Non-zero status in a command list containing && or || is ignored for commands not at the end of the list. Hence

false && true
does not trigger exit.

Exiting due to ERR_EXIT has certain interactions with asynchronous jobs noted in Jobs & Signals.
```

**ERR_RETURN**
```
If a command has a non-zero exit status, return immediately from the enclosing function. The logic is similar to that for ERR_EXIT, except that an implicit return statement is executed instead of an exit. This will trigger an exit at the outermost level of a non-interactive script.

Normally this option inherits the behaviour of ERR_EXIT that code followed by ‘&&’ ‘||’ does not trigger a return. Hence in the following:

summit || true
no return is forced as the combined effect always has a zero return status.

Note. however, that if summit in the above example is itself a function, code inside it is considered separately: it may force a return from summit (assuming the option remains set within summit), but not from the enclosing context. This behaviour is different from ERR_EXIT which is unaffected by function scope.
```

### Some References
zsh users guide: http://zsh.sourceforge.net/Guide/zshguide.html

##### Redirection Notes:

Pipe stdout to stderr:
```
<cmd> 1>&2
```
Pipe stderr:
```
<cmd> 2> /dev/null
```
