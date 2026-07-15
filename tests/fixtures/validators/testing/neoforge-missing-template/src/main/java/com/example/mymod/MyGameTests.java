package com.example.mymod;

import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.event.RegisterGameTestsEvent;

@EventBusSubscriber(modid = "mymod")
public final class MyGameTests {
    @SubscribeEvent
    public static void registerTests(RegisterGameTestsEvent event) {
    }
}
