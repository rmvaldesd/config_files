; Thunar keybinding overrides (the "go to path" bar, like macOS Cmd+Shift+G).
;
; WHY A SEPARATE FILE AND NOT THE WHOLE accels.scm: Thunar's ~/.config/Thunar/accels.scm
; is an AUTO-GENERATED dump of GTK's accel map (125 commented defaults + whatever the user
; changed). Versioning the whole file means it fights GTK: every time the user hits a new
; accelerator, GTK rewrites the dump and the file churns. So the repo keeps ONLY the
; overrides, and scripts/apply-thunar-accels.sh merges them into the user's file.
;
; Lines are exactly the format GTK expects inside accels.scm: uncommented
; (gtk_accel_path "<Actions>/ACTION" "KEY") entries. The installer is idempotent: it
; replaces a line when its ACTION already has an override, and appends it otherwise.
;
; KEY NAMES (GTK style, NOT macOS):
;   <Primary> = Ctrl      <Shift> = Shift      <Alt> = Alt      <Super> = the Windows key
;   So macOS Cmd+Shift+G is "<Primary><Shift>g" here.
;
; WHAT THE ACTION DOES: ThunarWindow/open-location opens the location entry (the path bar)
; where you can type or paste a path. Thunar ships it on Ctrl+L and, via a second action,
; on Alt+D. Both are kept; Ctrl+Shift+G is added because that is the macOS muscle memory.

; Type a path and jump to it (stock Thunar binding, kept).
(gtk_accel_path "<Actions>/ThunarWindow/open-location" "<Primary>l")

; Same bar, macOS-style: Ctrl+Shift+G (Cmd+Shift+G on a Mac).
(gtk_accel_path "<Actions>/ThunarWindow/open-location-alt" "<Primary><Shift>g")
