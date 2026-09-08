#!/bin/sh
#
# Prints the make target graph. The edges come from make's own rule database,
# so a target that gains a prerequisite shows it here without anyone saying so.
# The trailing descriptions are the `##` help text, and are only labels.

set -eu

cd "$(dirname "$0")/.."

{
	make -pnr 2>/dev/null \
		| sed -n 's/^\([a-zA-Z][A-Za-z0-9_.-]*\):\([^=]*\)$/EDGE \1\2/p' \
		| grep -v '^EDGE Makefile' \
		| sort -u
	sed -n 's/^\([a-zA-Z][A-Za-z0-9_.-]*\):.*## \(.*\)$/DESC \1 \2/p' Makefile
} | awk '
	function label(t) { return t (t in desc ? "  (" desc[t] ")" : "") }

	function walk(t, indent,    i, n, arr) {
		n = split(deps[t], arr, " ")
		for (i = 1; i <= n; i++) {
			print indent "\\_ " label(arr[i])
			walk(arr[i], indent "   ")
		}
	}

	$1 == "EDGE" {
		target = $2; $1 = ""; $2 = ""; sub(/^ +/, "")
		if (!(target in deps)) order[++count] = target
		deps[target] = $0
		next
	}

	$1 == "DESC" { target = $2; $1 = ""; $2 = ""; sub(/^ +/, ""); desc[target] = $0; next }

	END {
		print "Targets that pull something in"
		print ""
		for (i = 1; i <= count; i++) {
			t = order[i]
			if (deps[t] == "") continue
			print "  " label(t)
			walk(t, "  ")
			print ""
		}
		print "Targets that stand alone"
		print ""
		for (i = 1; i <= count; i++)
			if (deps[order[i]] == "") print "  " label(order[i])
	}
'
