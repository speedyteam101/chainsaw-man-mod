using RobotJack.Content.Items;
using Terraria;
using Terraria.GameContent.ItemDropRules;
using Terraria.Localization;
using Terraria.ModLoader;

namespace RobotJack.Common
{
	// So existing worlds (whose chests were generated before the mod) can still find one:
	// any enemy killed underground has a small chance to drop a Robot Trigger.
	public class RobotTriggerDrop : GlobalNPC
	{
		public const int DropChance = 150; // 1 in 150

		public override void ModifyGlobalLoot(GlobalLoot globalLoot) {
			globalLoot.Add(ItemDropRule.ByCondition(new UndergroundEnemyCondition(), ModContent.ItemType<RobotTrigger>(), DropChance));
		}

		private class UndergroundEnemyCondition : IItemDropRuleCondition
		{
			public bool CanDrop(DropAttemptInfo info) {
				NPC npc = info.npc;
				return npc != null
					&& !npc.friendly
					&& !npc.boss
					&& !npc.SpawnedFromStatue
					&& npc.lifeMax > 5
					&& npc.value > 0f
					&& npc.Center.Y > Main.worldSurface * 16.0;
			}

			public bool CanShowItemDropInUI() => false;

			public string GetConditionDescription() => Language.GetTextValue("Mods.RobotJack.DropConditions.Underground");
		}
	}
}
