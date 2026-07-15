# VHS tape for prompt-reference.nvim — renders demo/demo.mp4
# Record with:  cd demo && vhs demo.tape
# Requires: vhs (brew install vhs), and the plugin at the repo root.

Output demo.gif

Set Shell "bash"
Set FontSize 18
Set Width 1200
Set Height 760
Set Padding 20
Set Theme { "background": "#282c34", "foreground": "#ffffff", "black": "#1d1f21", "red": "#cc6666", "green": "#b5bd68", "yellow": "#f0c674", "blue": "#81a2be", "magenta": "#b294bb", "cyan": "#8abeb7", "white": "#c5c8c6", "brightBlack": "#666666", "brightRed": "#d54e53", "brightGreen": "#b9ca4a", "brightYellow": "#e7c547", "brightBlue": "#7aa6da", "brightMagenta": "#c397d8", "brightCyan": "#70c0b1", "brightWhite": "#eaeaea", "cursor": "#ffffff", "selection": "#373b41" }
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

# Open the sample file with the isolated demo config.
Hide
Type "nvim -u init.lua sample.lua"
Enter
Sleep 1.5s
Show

Sleep 1s

# --- Add the first reference: select verify() and give it a prompt ---
Type "4G"
Sleep 500ms
Type "V2j"
Sleep 800ms
Enter
Sleep 900ms
Type "Handle expired tokens here — add an expiry check."
Sleep 700ms
Enter
Sleep 1.4s

# --- Add a second reference from another region ---
Type "11G"
Sleep 400ms
Type "V"
Sleep 700ms
Enter
Sleep 900ms
Type "This route shdould return 401 when verify fails."
Sleep 700ms
Enter
Sleep 1.6s

# --- Open the review (Tab Tab) ---
Tab
Tab
Sleep 1.4s

# --- Show the help popup, then dismiss ---
Type "?"
Sleep 1.8s
Escape
Sleep 900ms

# --- Re-prompt: fix the typo in item 2's prompt (r shows its code as context) ---
Type "j"
Sleep 500ms
Type "r"
Sleep 1.2s
# prompt opens in insert with the old text prefilled; clear the line and retype
Escape
Sleep 300ms
Type "cc"
Sleep 400ms
Type "This route should return 401 when verify fails."
Sleep 700ms
Enter
Sleep 1.6s

# --- Copy the whole review to the clipboard and clear ---
Enter
Sleep 1.4s

# --- Paste the result into a scratch buffer to show the XML output ---
Type ":enew"
Enter
Sleep 400ms
Type `"+p`
Sleep 2.5s

Sleep 1s
