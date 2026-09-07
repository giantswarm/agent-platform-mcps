# Custom targets, auto-included by the root Makefile's `include Makefile.*.mk`.
# Lives outside the devctl-generated Makefile.gen.app.mk so it survives
# regeneration. DO NOT move these targets into the generated file.

##@ Custom

CHART_DIR ?= helm/agent-platform-mcps
GOLDEN_DIR ?= tests/golden
GUARDS_DIR ?= tests/guards
HELM ?= helm
RENDER_OUT ?= /tmp/agent-platform-mcps-render
# ABS versions a branch build `<semver>-dev.<branch>.<YYYY-MM-DD>.<HH-MM-SS>.<sha>`
# and `helm.sh/chart` is `<name>-<version>` cut to 63 characters. When the cut
# lands on a "." the label value is invalid and the API server rejects every
# labelled object (giantswarm/model-manager#59 hit it with a 16-character
# branch). For this chart's name a 12-character branch puts the "." exactly at
# position 63, so this version exercises the helper's trailing-character trim.
LABEL_GUARD_VERSION ?= 0.9.0-dev.chart-labels.2026-09-07.17-06-51.1772009

# The chart renders CRs only, so its contract is the rendered YAML: every
# tests/golden/<case>/values.yaml renders byte for byte into expected.yaml
# (the release name and namespace match the fleet's HelmRelease). The guard
# cases under tests/guards/ must FAIL the render with the message on their
# first line (`# expect: <substring>`); the schema is skipped there so the
# template-time guard itself is what gets exercised. The label guard packages
# the chart with LABEL_GUARD_VERSION (as ABS does on a branch) and asserts every
# rendered `helm.sh/chart` value is a valid label value.
.PHONY: verify-render
verify-render: ## Diff every tests/golden case against its expected.yaml, assert the tests/guards cases fail with their expected message, and assert helm.sh/chart stays a valid label value for a branch-build version.
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
	@set -e; rm -rf $(RENDER_OUT)/label-guard; mkdir -p $(RENDER_OUT)/label-guard; \
		$(HELM) package $(CHART_DIR) --version $(LABEL_GUARD_VERSION) -d $(RENDER_OUT)/label-guard >/dev/null; \
		$(HELM) template agent-platform-mcps $(RENDER_OUT)/label-guard/agent-platform-mcps-$(LABEL_GUARD_VERSION).tgz -n agent-platform -f $(GOLDEN_DIR)/tool-group/values.yaml > $(RENDER_OUT)/label-guard/render.yaml; \
		labels=$$(sed -nE 's/^[[:space:]]*helm\.sh\/chart:[[:space:]]*"?([^"]*)"?[[:space:]]*$$/\1/p' $(RENDER_OUT)/label-guard/render.yaml | sort -u); \
		[ -n "$$labels" ] || { echo "FAIL: label guard rendered no helm.sh/chart label"; exit 1; }; \
		for l in $$labels; do \
			if ! echo "$$l" | grep -Eq '^[A-Za-z0-9]([-A-Za-z0-9_.]{0,61}[A-Za-z0-9])?$$'; then \
				echo "FAIL: helm.sh/chart value '$$l' is not a valid label value (chart version $(LABEL_GUARD_VERSION))"; exit 1; \
			fi; \
		done; \
		echo "ok: guard helm.sh/chart label ($$labels)"

.PHONY: update-golden
update-golden: ## Re-render every tests/golden/<case>/expected.yaml from its values.yaml. Review the diff before committing.
	@echo "====> $@ ($(CHART_DIR))"
	@set -e; for d in $(GOLDEN_DIR)/*/; do \
		$(HELM) template agent-platform-mcps $(CHART_DIR) -n agent-platform -f $$d/values.yaml > $$d/expected.yaml; \
		echo "wrote $$d/expected.yaml"; \
	done
