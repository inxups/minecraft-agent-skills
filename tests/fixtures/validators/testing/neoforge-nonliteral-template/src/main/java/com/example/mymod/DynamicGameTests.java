package com.example.mymod;

import net.minecraft.gametest.framework.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;
import net.neoforged.neoforge.gametest.GameTestHolder;

@GameTestHolder("mymod")
public final class DynamicGameTests {
    private static final String TEMPLATE = "mymod:empty";

    @GameTest(template = TEMPLATE)
    public static void smoke(GameTestHelper helper) {
        helper.succeed();
    }
}
