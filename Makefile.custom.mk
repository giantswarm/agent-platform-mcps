# Custom targets, auto-included by the root Makefile's `include Makefile.*.mk`.
# Lives outside the devctl-generated Makefile.gen.app.mk so it survives
# regeneration. DO NOT move these targets into the generated file.

##@ Custom

CHART_DIR ?= helm/agent-platform-mcps
GOLDEN_DIR ?= tests/golden
GUARDS_DIR ?= tests/guards
HELM ?= helm
RENDER_OUT ?= /tmp/agent-platform-mcps-render

# The chart renders CRs only, so its contract is the rendered YAML: every
# tests/golden/<case>/values.yaml renders byte for byte into expected.yaml
# (the release name and namespace match the fleet's HelmRelease). The guard
# cases under tests/guards/ must FAIL the render with the message on their
# first line (`# expect: <substring>`); the schema is skipped there so the
# template-time guard itself is what gets exercised.
.PHONY: verify-render
verify-render: ## Diff every tests/golden case against its expected.yaml and assert the tests/guards cases fail with their expected message.
	@echo "====> $@ ($(CHART_DIR))"
	@mkdir -p $(RENDER_OUT)
	@set -e; for d in $(GOLDEN_DIR)/*/; do \
		c=$$(basename $$d); \
		$(HELM) template agent-platform-mcps $(CHART_DIR) -n agent-platform -f $$d/values.yaml > $(RENDER_OUT)/$$c.yaml; \
		if ! diff -u $$d/expected.yaml $(RENDER_OUT)/$$c.yaml; then \
			echo "FAIL: golden case $$c renders differently from $$d/expected.yaml (run 'make update-golden' if the change is intended)"; exit 1; \
		fi; \
		echo "ok: golden $$c"; \
	done
	@set -e; for f in $(GUARDS_DIR)/*.values.yaml; do \
		c=$$(basename $$f .values.yaml); \
		want=$$(sed -n '1s/^# expect: //p' $$f); \
		[ -n "$$want" ] || { echo "FAIL: $$f has no '# expect: <substring>' first line"; exit 1; }; \
		if $(HELM) template agent-platform-mcps $(CHART_DIR) -n agent-platform --skip-schema-validation -f $$f > $(RENDER_OUT)/guard-$$c.out 2>&1; then \
			echo "FAIL: guard case $$c rendered instead of failing"; cat $(RENDER_OUT)/guard-$$c.out; exit 1; \
		fi; \
		if ! grep -qF -- "$$want" $(RENDER_OUT)/guard-$$c.out; then \
			echo "FAIL: guard case $$c failed for the wrong reason (want '$$want'):"; cat $(RENDER_OUT)/guard-$$c.out; exit 1; \
		fi; \
		echo "ok: guard $$c"; \
	done

.PHONY: update-golden
update-golden: ## Re-render every tests/golden/<case>/expected.yaml from its values.yaml. Review the diff before committing.
	@echo "====> $@ ($(CHART_DIR))"
	@set -e; for d in $(GOLDEN_DIR)/*/; do \
		$(HELM) template agent-platform-mcps $(CHART_DIR) -n agent-platform -f $$d/values.yaml > $$d/expected.yaml; \
		echo "wrote $$d/expected.yaml"; \
	done
