package com.perwd.orange.plugin;

import java.util.List;
import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.World;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabExecutor;

final class OrangeCommand implements TabExecutor {
    private static final String P = ChatColor.GOLD + "[Orange] " + ChatColor.RESET;
    private final OrangePlugin plugin;

    OrangeCommand(OrangePlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        String sub = args.length == 0 ? "status" : args[0].toLowerCase();
        switch (sub) {
            case "status" -> status(sender);
            case "reload" -> {
                plugin.applyConfig();
                sender.sendMessage(P + "Config reloaded.");
            }
            case "pregen" -> pregen(sender, label, args);
            default -> sender.sendMessage(P + "Usage: /" + label + " <status|reload|pregen>");
        }
        return true;
    }

    private void pregen(CommandSender sender, String label, String[] args) {
        Pregenerator pregen = plugin.pregenerator();
        if (args.length == 2 && args[1].equalsIgnoreCase("stop")) {
            sender.sendMessage(P + pregen.stop());
            return;
        }
        if (args.length == 2 && args[1].equalsIgnoreCase("status")) {
            sender.sendMessage(P + "Pre-generation: " + pregen.status());
            return;
        }
        if (args.length != 3) {
            sender.sendMessage(P + "Usage: /" + label + " pregen <world> <radius in blocks> | stop | status");
            return;
        }
        if (!Pregenerator.supported()) {
            sender.sendMessage(P + "Pre-generation needs Paper's async chunk API (Paper or a Paper fork).");
            return;
        }
        World world = Bukkit.getWorld(args[1]);
        if (world == null) {
            sender.sendMessage(P + "Unknown world " + args[1]);
            return;
        }
        int radius;
        try {
            radius = Integer.parseInt(args[2]);
        } catch (NumberFormatException e) {
            sender.sendMessage(P + "Radius must be a number of blocks, e.g. 5000");
            return;
        }
        sender.sendMessage(P + pregen.start(world, radius));
    }

    private void status(CommandSender sender) {
        TickMonitor m = plugin.tickMonitor();
        sender.sendMessage(P + "TPS " + color(m.tps(100)) + ChatColor.GRAY + " (5s) "
                + color(m.tps(1200)) + ChatColor.GRAY + " (1m)");
        if (PaperSupport.hasPaperTickTime()) {
            double mspt = Bukkit.getServer().getAverageTickTime();
            ChatColor c = mspt < 40 ? ChatColor.GREEN : mspt < 50 ? ChatColor.YELLOW : ChatColor.RED;
            sender.sendMessage(P + "MSPT " + c + String.format("%.1f", mspt) + ChatColor.GRAY + " / 50.0");
        }
        Runtime rt = Runtime.getRuntime();
        long usedMb = (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
        sender.sendMessage(P + "Memory " + usedMb + " / " + rt.maxMemory() / (1024 * 1024) + " MB");
        for (World world : Bukkit.getWorlds()) {
            sender.sendMessage(ChatColor.GRAY + "  " + world.getName() + ": "
                    + world.getLoadedChunks().length + " chunks, "
                    + world.getEntities().size() + " entities, "
                    + world.getPlayers().size() + " players, sim " + world.getSimulationDistance()
                    + " / view " + world.getViewDistance());
        }
        TickGovernor g = plugin.governor();
        sender.sendMessage(P + "Governor: " + (g.active() ? "on, last change: " + g.lastAction() : "off"));
        EntityLimiter l = plugin.entityLimiter();
        sender.sendMessage(P + "Entity limiter: " + (l.enabled() ? "on, " + l.blocked() + " spawns blocked" : "off"));
        sender.sendMessage(P + "Pre-generation: " + plugin.pregenerator().status());
    }

    private static String color(double tps) {
        ChatColor c = tps >= 19.5 ? ChatColor.GREEN : tps >= 17 ? ChatColor.YELLOW : ChatColor.RED;
        return c + String.format("%.2f", tps);
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        if (args.length == 1) {
            return filter(List.of("status", "reload", "pregen"), args[0]);
        }
        if (args.length == 2 && args[0].equalsIgnoreCase("pregen")) {
            List<String> options = new java.util.ArrayList<>(List.of("stop", "status"));
            Bukkit.getWorlds().forEach(w -> options.add(w.getName()));
            return filter(options, args[1]);
        }
        return List.of();
    }

    private static List<String> filter(List<String> options, String prefix) {
        return options.stream().filter(s -> s.toLowerCase().startsWith(prefix.toLowerCase())).toList();
    }
}
