package com.example.mymod;

import net.minecraft.core.Holder;
import net.minecraft.gametest.framework.BuiltinTestFunctions;
import net.minecraft.gametest.framework.FunctionGameTestInstance;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.gametest.framework.TestData;
import net.minecraft.gametest.framework.TestEnvironmentDefinition;
import net.minecraft.resources.Identifier;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.event.RegisterGameTestsEvent;

@EventBusSubscriber(modid = "mymod")
public final class DynamicGameTests {
    private static final String STRUCTURE_PATH = "empty";

    @SubscribeEvent
    public static void registerTests(RegisterGameTestsEvent event) {
        Holder<TestEnvironmentDefinition<?>> environment = event.registerEnvironment(
            Identifier.fromNamespaceAndPath("mymod", "default")
        );
        TestData<Holder<TestEnvironmentDefinition<?>>> data = new TestData<>(
            environment,
            Identifier.fromNamespaceAndPath("mymod", STRUCTURE_PATH),
            1,
            0,
            false
        );
        event.registerTest(
            Identifier.fromNamespaceAndPath("mymod", "dynamic_smoke"),
            new FunctionGameTestInstance(BuiltinTestFunctions.ALWAYS_PASS, data)
        );
    }

    public static void smoke(GameTestHelper helper) {
        helper.succeed();
    }
}
