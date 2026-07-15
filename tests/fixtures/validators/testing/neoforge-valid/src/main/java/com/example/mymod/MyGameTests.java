package com.example.mymod;

import net.minecraft.core.Holder;
import net.minecraft.gametest.framework.BuiltinTestFunctions;
import net.minecraft.gametest.framework.FunctionGameTestInstance;
import net.minecraft.gametest.framework.TestData;
import net.minecraft.gametest.framework.TestEnvironmentDefinition;
import net.minecraft.resources.Identifier;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.event.RegisterGameTestsEvent;

@EventBusSubscriber(modid = "mymod")
public final class MyGameTests {
    @SubscribeEvent
    public static void registerTests(RegisterGameTestsEvent event) {
        Holder<TestEnvironmentDefinition<?>> environment = event.registerEnvironment(
            Identifier.fromNamespaceAndPath("mymod", "default")
        );
        TestData<Holder<TestEnvironmentDefinition<?>>> data = new TestData<>(
            environment,
            Identifier.fromNamespaceAndPath("mymod", "empty"),
            1,
            0,
            false
        );
        event.registerTest(
            Identifier.fromNamespaceAndPath("mymod", "java_smoke"),
            new FunctionGameTestInstance(BuiltinTestFunctions.ALWAYS_PASS, data)
        );
    }
}
