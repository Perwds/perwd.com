package com.example.orangemod;

import com.perwd.orange.api.ModContext;
import com.perwd.orange.api.OrangeMod;
import com.perwd.orange.hooks.OrangeHooks;

public final class ExampleMod implements OrangeMod {
    @Override
    public void onLoad(ModContext context) {
        // Fired by StopHookPatch from inside MinecraftServer#stopServer.
        OrangeHooks.on("example:server-stopping", args ->
                context.logger().info("The server is stopping. Instance: " + args[0].getClass().getName()));
        context.logger().info("Hello from the example mod!");
    }
}
