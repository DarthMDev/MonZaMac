#!/bin/bash
# Keep the shader source encoding compatible with a C string literal.
set -euo pipefail
LC_ALL=C tr -d '\r' < "$1" | LC_ALL=C tr '\200-\377' '?' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$/\\n"/' > "$2"
