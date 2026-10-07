package com.perwd.orange.plugin;

import org.bukkit.command.PluginCommand;
import org.bukkit.plugin.java.JavaPlugin;

public final class OrangePlugin extends JavaPlugin {
    private TickMonitor tickMonitor;
    private TickGovernor governor;
    private EntityLimiter entityLimiter;
    private Pregenerator pregenerator;
    private PingManager pingManager;

    @Override
    public void onEnable() {
        saveDefaultConfig();
        tickMonitor = new TickMonitor();
        getServer().getScheduler().runTaskTimer(this, tickMonitor, 1L, 1L);

        governor = new TickGovernor(this, tickMonitor);
        entityLimiter = new EntityLimiter();
        pregenerator = new Pregenerator(this, tickMonitor);
        pingManager = new PingManager(this);
        getServer().getPluginManager().registerEvents(pingManager, this);
        getServer().getPluginManager().registerEvents(entityLimiter, this);
        applyConfig();

        PluginCommand command = getCommand("orange");
        if (command != null) {
            OrangeCommand executor = new OrangeCommand(this);
            command.setExecutor(executor);
            command.setTabCompleter(executor);
        }
    }

    @Override
    public void onDisable() {
        if (governor != null) {
            governor.stop();
        }
        if (pingManager != null) {
            pingManager.stop();
        }
        if (pregenerator != null && pregenerator.running()) {
            pregenerator.stop();
        }
    }

    void applyConfig() {
        reloadConfig();
        governor.configure(getConfig().getConfigurationSection("governor"));
        entityLimiter.configure(getConfig().getConfigurationSection("entity-limiter"), getLogger());
        pregenerator.configure(getConfig().getConfigurationSection("pregen"));
        pingManager.configure(getConfig().getConfigurationSection("ping"));
    }

    TickMonitor tickMonitor() {
        return tickMonitor;
    }

    TickGovernor governor() {
        return governor;
    }

    EntityLimiter entityLimiter() {
        return entityLimiter;
    }

    PingManager pingManager() {
        return pingManager;
    }

    Pregenerator pregenerator() {
        return pregenerator;
    }
}
