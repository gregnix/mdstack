---
title: puts
section: n
manual-section: Tcl Built-In Commands
version: 9.0
see-also: gets read open close
---

# puts

Writes characters on an I/O channel.

## Synopsis

::: {.synopsis}
[puts]{.cmd} [-nonewline]{.optlit} [channelId]{.optarg} [string]{.arg}
:::

## Description

Writes *string* followed by a newline character to the specified
[channelId]. If [-nonewline]{.optlit} is given, the trailing newline
is suppressed.

The [channelId] argument must be a channel identifier such as the
return value from a previous [open] or [socket] call. It may also
be **stdout**, **stderr**, or **stdin**.

If [channelId]{.arg} is omitted, the string is written to **stdout**.

### Output Buffering

Output to a channel is normally buffered internally by Tcl. The [flush]
command forces any buffered output to be written immediately. The
buffering behavior can be controlled with [fconfigure]:

```tcl
fconfigure stdout -buffering line
fconfigure $fd -buffering full -buffersize 8192
```

## Arguments

::: {.arguments}
[-nonewline]{.optlit}
:   If specified, a trailing newline character is *not* appended to
    the output.

[channelId]{.optarg}
:   An I/O channel identifier. If omitted, defaults to **stdout**.

[string]{.arg}
:   The text to write. May contain embedded newlines, Unicode characters,
    and backslash substitutions such as `\n` and `\t`.
:::

## Return Value

[puts]{.cmd} returns an empty string.

## Errors

If an error occurs during output, Tcl raises an error. Common cases:

- Writing to a closed channel
- Disk full or I/O failure
- Encoding conversion errors

## Examples

::: {.example}
### Basic Output

```tcl
puts "Hello, World!"
```

Writes `Hello, World!` followed by a newline to **stdout**.
:::

::: {.example}
### Writing to stderr Without Newline

```tcl
puts -nonewline stderr "Error: "
puts stderr "something went wrong"
```

Produces: `Error: something went wrong` on the standard error channel.
:::

::: {.example}
### Writing to a File

```tcl
set fd [open "output.txt" w]
puts $fd "Line 1"
puts $fd "Line 2"
close $fd
```

Creates `output.txt` with two lines.
:::

::: {.example}
### Multi-Line Output

```tcl
puts [string cat \
    "Name:    Tcl\n" \
    "Version: 9.0\n" \
    "Status:  stable"]
```
:::

## Related C API

::: {.synopsis}
[int]{.ret} [Tcl_WriteObj]{.ccmd} [channel, objPtr]{.cargs}

[int]{.ret} [Tcl_WriteChars]{.ccmd} [channel, charStr, numChars]{.cargs}

[int]{.ret} [Tcl_Flush]{.ccmd} [channel]{.cargs}
:::

These C functions are the low-level equivalents used internally by the
Tcl runtime. [Tcl_WriteObj]{.ccmd} writes the byte representation of
a Tcl object, while [Tcl_WriteChars]{.ccmd} writes a UTF-8 string.

## Comparison: puts vs. chan puts

| Feature | [puts]{.cmd} | [chan puts]{.cmd} |
|---------|:------------:|:-----------------:|
| Syntax  | Traditional  | Ensemble          |
| Channel | Optional     | Required          |
| Result  | Identical    | Identical         |

Since Tcl 8.5, [chan puts]{.cmd} provides the same functionality in
the [chan] ensemble style. Both commands are fully interchangeable.

## See Also

[gets], [read], [open], [close], [flush], [fconfigure], [socket], [chan]

[gets]: gets.md "Read a Line"
[read]: read.md "Read Characters"
[open]: open.md "Open a Channel"
[close]: close.md "Close a Channel"
[flush]: flush.md "Flush Buffered Output"
[fconfigure]: fconfigure.md "Configure Channel Options"
[socket]: socket.md "Open a TCP Socket"
[chan]: chan.md "Channel Ensemble"
[channelId]: Tcl_OpenFileChannel.md
