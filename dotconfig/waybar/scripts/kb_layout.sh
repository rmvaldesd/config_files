#!/bin/bash
# Extract the current active layout index safely from Hyprland JSON data
INDEX=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_layout_index')

if [ "$INDEX" -eq 0 ]; then
    echo "LatAm"
else
    echo "ES"
fi

