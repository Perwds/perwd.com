package com.perwd.orange.plugin;

import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.bukkit.Bukkit;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.scheduler.BukkitTask;

/**
 * Tracks each player's ping and jitter, and helps players on slow connections.
 *
 * <p>Adaptive send distance: when a player's ping stays high, Orange sends them fewer chunks
 * (Paper's per-player send view distance). Simulation is untouched (the world ticks exactly as
 * before); the player just sees a little less far. A congested connection then spends its
 * bandwidth on movement, entity and block updates instead of a queue of terrain, which is what
 * makes a high-ping player feel laggy.
 */
final class PingManager implements Listener {
    private final OrangePlugin plugin;
    private final Map<UUID, Stats> stats = new HashMap<>();
    private BukkitTask task;

    private boolean adaptive;
    private int highPing;
    private int recoverPing;
    private int reducedDistance;
    private int holdSeconds;

    PingManager(OrangePlugin plugin) {
        this.plugin = plugin;
    }

    static boolean adaptiveSupported() {
        return PaperSupport.hasSendViewDistance();
    }

    void configure(ConfigurationSection config) {
        restoreAll();
        adaptive = config != null && config.getBoolean("adaptive-send-distance.enabled", true) && adaptiveSupported();
        highPing = config == null ? 250 : config.getInt("adaptive-send-distance.high-ping-ms", 250);
        recoverPing = config == null ? 180 : config.getInt("adaptive-send-distance.recover-ping-ms", 180);
        reducedDistance = Math.max(2, config == null ? 6 : config.getInt("adaptive-send-distance.send-distance", 6));
        holdSeconds = Math.max(5, config == null ? 30 : config.getInt("adaptive-send-distance.hold-seconds", 30));
        if (task == null) {
            task = Bukkit.getScheduler().runTaskTimer(plugin, this::sample, 20L, 20L);
        }
    }

    void stop() {
        if (task != null) {
            task.cancel();
            task = null;
        }
        restoreAll();
    }

    private void sample() {
        long now = System.currentTimeMillis();
        for (Player player : Bukkit.getOnlinePlayers()) {
            Stats s = stats.computeIfAbsent(player.getUniqueId(), id -> new Stats());
            s.add(player.getPing());
            if (!adaptive || s.samples < 10) {
                continue;
            }
            if (s.originalSendDistance == null && s.average > highPing && now - s.lastChange > holdSeconds * 1000L) {
                int current = player.getSendViewDistance();
                int effective = current < 0 ? player.getWorld().getViewDistance() : current;
                if (effective > reducedDistance) {
                    s.originalSendDistance = current;
                    s.lastChange = now;
                    player.setSendViewDistance(reducedDistance);
                }
            } else if (s.originalSendDistance != null && s.average < recoverPing && now - s.lastChange > holdSeconds * 1000L) {
                player.setSendViewDistance(s.originalSendDistance);
                s.originalSendDistance = null;
                s.lastChange = now;
            }
        }
    }

    private void restoreAll() {
        for (Player player : Bukkit.getOnlinePlayers()) {
            Stats s = stats.get(player.getUniqueId());
            if (s != null && s.originalSendDistance != null) {
                player.setSendViewDistance(s.originalSendDistance);
                s.originalSendDistance = null;
            }
        }
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent event) {
        stats.remove(event.getPlayer().getUniqueId());
    }

    boolean adaptive() {
        return adaptive;
    }

    int reducedCount() {
        int n = 0;
        for (Stats s : stats.values()) {
            if (s.originalSendDistance != null) {
                n++;
            }
        }
        return n;
    }

    /** Online players, worst connection first. */
    List<Player> playersByPing() {
        return Bukkit.getOnlinePlayers().stream()
                .map(p -> (Player) p)
                .sorted(Comparator.comparingDouble((Player p) -> stats(p).average).reversed())
                .toList();
    }

    Stats stats(Player player) {
        return stats.computeIfAbsent(player.getUniqueId(), id -> new Stats());
    }

    static final class Stats {
        double average = -1;
        double jitter;
        int last = -1;
        int samples;
        Integer originalSendDistance;
        long lastChange;

        void add(int ping) {
            if (ping < 0) {
                return;
            }
            // Exponential moving averages over roughly the last 20 seconds.
            average = average < 0 ? ping : average * 0.9 + ping * 0.1;
            if (last >= 0) {
                jitter = jitter * 0.9 + Math.abs(ping - last) * 0.1;
            }
            last = ping;
            samples++;
        }

        boolean reduced() {
            return originalSendDistance != null;
        }
    }
}
