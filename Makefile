.PHONY: help install install-copy uninstall auto-activate clean checkpoint contribute contribute-push

help:
	@echo "Workflow targets:"
	@echo "  make install                    Symlink workflow into parent project (submodule mode)"
	@echo "  make install-copy TARGET=<dir>  Copy workflow into <dir> (no submodule)"
	@echo "  make uninstall                  Remove workflow from parent project"
	@echo "  make auto-activate              Safe activation guard (used by SessionStart hook)"
	@echo "  make clean [ARGS=...]           Audit + clean workflow runtime artifacts"
	@echo "  make checkpoint REASON='...'    Emergency 0-token checkpoint"
	@echo "  make contribute DESC='...'      Branch the submodule for a PR upstream"
	@echo "  make contribute-push            Push contrib branch + open PR"

install:
	@bash .claude/workflow/install.sh symlink $(ARGS)

install-copy:
	@bash .claude/workflow/install.sh copy --target "$(TARGET)" $(ARGS)

uninstall:
	@bash .claude/workflow/install.sh uninstall $(ARGS)

auto-activate:
	@bash .claude/workflow/install.sh auto-activate

clean:
	@bash .claude/workflow/clean.sh $(ARGS)

checkpoint:
	@bash .claude/workflow/checkpoint.sh "$(REASON)"

contribute:
	@bash .claude/workflow/contribute.sh "$(DESC)"

contribute-push:
	@bash .claude/workflow/contribute.sh --push
