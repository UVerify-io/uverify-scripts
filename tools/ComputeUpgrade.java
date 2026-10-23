import co.nstant.in.cbor.CborDecoder;
import co.nstant.in.cbor.model.ByteString;
import com.bloxbean.cardano.client.address.AddressProvider;
import com.bloxbean.cardano.client.common.model.Network;
import com.bloxbean.cardano.client.common.model.Networks;
import com.bloxbean.cardano.client.plutus.blueprint.PlutusBlueprintUtil;
import com.bloxbean.cardano.client.plutus.blueprint.model.PlutusVersion;
import com.bloxbean.cardano.client.plutus.spec.BytesPlutusData;
import com.bloxbean.cardano.client.plutus.spec.PlutusScript;
import com.bloxbean.cardano.client.plutus.spec.PlutusV3Script;
import com.bloxbean.cardano.client.util.HexUtil;
import io.uverify.backend.util.ValidatorUtils;
import scalus.bloxbean.ScalusScriptUtils;

import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ComputeUpgrade {
    public static void main(String[] args) throws Exception {
        String proxyTxHash = args[0];
        int proxyOutputIndex = Integer.parseInt(args[1]);
        String blueprintPath = args[2];
        // Optional 4th arg: "mainnet" or "preprod" (default). Only affects the
        // bech32 address printouts used for verification; the POST body is the
        // parameterized compiled code and is network-independent.
        String networkName = args.length > 3 ? args[3].toLowerCase() : "preprod";
        Network network = networkName.equals("mainnet") ? Networks.mainnet() : Networks.preprod();

        PlutusScript proxyContract = ValidatorUtils.getUverifyProxyContract(proxyTxHash, proxyOutputIndex);
        String proxyScriptHash = ValidatorUtils.validatorToScriptHash(proxyContract);
        String stateTokenName = ValidatorUtils.getProxyStateTokenName(proxyTxHash, proxyOutputIndex);

        System.out.println("network            = " + networkName);
        System.out.println("proxy_policy_id    = " + proxyScriptHash);
        System.out.println("state_token_name   = " + stateTokenName);
        System.out.println("proxy_address      = " + AddressProvider.getEntAddress(proxyContract, network).toBech32());

        String blueprint = Files.readString(Path.of(blueprintPath));
        Matcher matcher = Pattern.compile(
                "\"title\":\\s*\"uverify_v2\\.uverify_state\\.withdraw\".*?\"compiledCode\":\\s*\"([0-9a-f]+)\"",
                Pattern.DOTALL).matcher(blueprint);
        if (!matcher.find()) throw new IllegalStateException("uverify_v2 not found in blueprint");
        String v2CompiledCode = matcher.group(1);

        PlutusScript plainV2 = PlutusBlueprintUtil.getPlutusScriptFromCompiledCode(v2CompiledCode, PlutusVersion.v3);
        String parameterizedCborHex = ScalusScriptUtils.applyParamsToScript(plainV2.getCborHex(),
                BytesPlutusData.of(HexUtil.decodeHexString(proxyScriptHash)),
                BytesPlutusData.of(HexUtil.decodeHexString(stateTokenName)));
        PlutusScript parameterizedScript = PlutusV3Script.builder().cborHex(parameterizedCborHex).build();

        String v2ScriptHash = ValidatorUtils.validatorToScriptHash(parameterizedScript);
        System.out.println("v2_script_hash     = " + v2ScriptHash);
        System.out.println("v2_reward_address  = " + AddressProvider.getRewardAddress(parameterizedScript, network).toBech32());

        ByteString outer = (ByteString) CborDecoder.decode(HexUtil.decodeHexString(parameterizedCborHex)).get(0);
        String postBody = HexUtil.encodeHexString(outer.getBytes());

        PlutusScript roundTrip = PlutusBlueprintUtil.getPlutusScriptFromCompiledCode(postBody, PlutusVersion.v3);
        if (!ValidatorUtils.validatorToScriptHash(roundTrip).equals(v2ScriptHash)) {
            throw new IllegalStateException("round-trip script hash mismatch");
        }
        System.out.println("post_body_ok       = true");

        // What the backend will compute once its hardcoded blob is swapped to the v2 compiled code
        String backendCborHex = ScalusScriptUtils.applyParamsToScript(
                PlutusBlueprintUtil.getPlutusScriptFromCompiledCode(v2CompiledCode, PlutusVersion.v3).getCborHex(),
                BytesPlutusData.of(HexUtil.decodeHexString(proxyScriptHash)),
                BytesPlutusData.of(HexUtil.decodeHexString(stateTokenName)));
        System.out.println("backend_match      = " + backendCborHex.equals(parameterizedCborHex));

        Files.writeString(Path.of("upgrade-post-body.txt"), postBody);
        System.out.println("post body written to upgrade-post-body.txt (" + postBody.length() / 2 + " bytes)");

        // Current v1 script hash for comparison (backend's hardcoded blob)
        PlutusScript currentState = ValidatorUtils.getUVerifyStateContract(proxyTxHash, proxyOutputIndex);
        System.out.println("current_v1_hash    = " + ValidatorUtils.validatorToScriptHash(currentState));
        System.out.println("v1_reward_address  = " + AddressProvider.getRewardAddress(currentState, network).toBech32());
    }
}
