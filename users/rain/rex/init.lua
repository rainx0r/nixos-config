-- Keybindings ported from ../ghostty/config.
-- Font, theme, cursor and copy-on-select are app settings in Rex, not init.lua.

rex.bind("cmd+x", "pane.close")

rex.bind("cmd+shift+h", "pane.focus.left")
rex.bind("cmd+shift+j", "pane.focus.down")
rex.bind("cmd+shift+k", "pane.focus.up")
rex.bind("cmd+shift+l", "pane.focus.right")

rex.bind("cmd+ctrl+h", "pane.split.left")
rex.bind("cmd+ctrl+j", "pane.split.down")
rex.bind("cmd+ctrl+k", "pane.split.up")
rex.bind("cmd+ctrl+l", "pane.split.right")

rex.unbind("cmd+alt+left")
rex.unbind("cmd+alt+down")
rex.unbind("cmd+alt+up")
rex.unbind("cmd+alt+right")
