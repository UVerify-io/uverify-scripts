# tools

## ComputeUpgrade.java

Computes the request body for `POST /api/v1/library/upgrade/proxy`: the
`uverify_v2` state script parameterized with the target network's
`proxy_policy_id` and `state_token_name`, in `compiledCode` form.

It reuses the backend's own parameterization code path (`ValidatorUtils` +
Scalus), so the deployed script is guaranteed byte-identical to what the
backend computes after its hardcoded state contract blob is swapped to v2.

Run it against the compiled backend classpath:

```bash
cd ../uverify-backend
export JAVA_HOME=<jdk21>
./mvnw -q compile dependency:build-classpath -Dmdep.outputFile=/tmp/cp.txt -DskipTests
java -cp "target/classes:$(cat /tmp/cp.txt)" \
  ../uverify-scripts/tools/ComputeUpgrade.java \
  <PROXY_TX_HASH> <PROXY_OUTPUT_INDEX> ../uverify-scripts/plutus.json
```

Output:

- `proxy_policy_id`, `state_token_name`, proxy address
- `v2_script_hash` and reward address (what the proxy datum will point at)
- `current_v1_hash` (what the backend's hardcoded blob currently resolves to)
- `upgrade-post-body.txt` in the working directory — the exact body to POST

`post_body_ok = true` confirms the round-trip through the endpoint's
deserialization reproduces the same script hash. `backend_match = true`
confirms the backend will derive the identical script from the same blueprint
code after the swap.

Addresses are printed with the preprod/testnet network tag. For mainnet swap
`Networks.preprod()` for `Networks.mainnet()` before running.

See `docs/2026-07-13-uverify-v2-upgrade-runbook.md` in the workspace root for
the full upgrade procedure.
