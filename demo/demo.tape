# VHS tape for prompt-reference.nvim — renders demo/demo.gif
# Recorded with the author's real Neovim config (no -u), against the two
# sample files in this dir, to show the multi-file review path.
# Record with:  cd demo && vhs demo.tape   (needs vhs; on macOS you may need
# ROD_BROWSER_BIN pointing at a real Chrome — see README "Development").

Output demo.gif

Set Shell "bash"
Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 18
Set Width 1200
Set Height 760
Set Padding 20
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

# Open both sample files with the real config; wait for plugins to load.
Hide
Type "nvim auth.lua routes.lua"
Enter
Sleep 3s
Show

Sleep 1s

# --- File 1 (auth.lua): stage verify() with a prompt ---
Type "4G"
Sleep 500ms
Type "V2j"
Sleep 800ms
Enter
Sleep 900ms
Type "Handle expired tokens here — add an expiry check."
Sleep 700ms
Enter
Sleep 1.5s

# --- Switch to file 2 (routes.lua) via bufferline (Space ]) ---
Space
Type "]"
Sleep 1.4s

# --- File 2 (routes.lua): stage the /me route with a prompt ---
Type "7G"
Sleep 500ms
Type "V"
Sleep 800ms
Enter
Sleep 900ms
Type "This route should return 401 when verify fails."
Sleep 700ms
Enter
Sleep 1.6s

# --- Open the multi-file review (Tab Tab): two files, two prompts ---
Tab
Tab
Sleep 2s

# --- Show the help popup, then dismiss ---
Type "?"
Sleep 1.8s
Escape
Sleep 900ms

# --- Re-prompt the second item (r shows its code as context) ---
Type "j"
Sleep 500ms
Type "r"
Sleep 1.2s
Escape
Sleep 300ms
Type "cc"
Sleep 400ms
Type "Return 401 (not 500) when verify throws."
Sleep 700ms
Enter
Sleep 1.6s

# --- Copy the whole review to the clipboard and clear ---
Enter
Sleep 1.4s

# --- Paste the result to show the multi-file XML output ---
Type ":enew"
Enter
Sleep 400ms
Type `"+p`
Sleep 3s

Sleep 1s
