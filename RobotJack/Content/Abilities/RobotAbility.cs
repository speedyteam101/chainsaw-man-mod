using RobotJack.Common;
using System.Collections.Generic;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Abilities
{
	// Base class for Robot Jack's ability items.
	// RobotJackPlayer puts these in the player's inventory while transformed and removes them afterwards.
	// They can't be kept: they vanish when the form ends or when they're dropped in the world.
	public abstract class RobotAbility : ModItem
	{
		// Every ability, in load order.
		public static readonly List<RobotAbility> All = new();

		// Extra damage multiplier unlocked by beating bosses (x1 at the start of a world, up to x3 after the Moon Lord).
		public static float ProgressionMultiplier() {
			float mult = 1f;
			if (NPC.downedBoss3) mult += 0.3f;         // Skeletron
			if (Main.hardMode) mult += 0.4f;           // Wall of Flesh
			if (NPC.downedMechBossAny) mult += 0.3f;   // any mechanical boss
			if (NPC.downedPlantBoss) mult += 0.4f;     // Plantera
			if (NPC.downedMoonlord) mult += 0.6f;      // Moon Lord
			return mult;
		}

		public override void SetStaticDefaults() {
			Item.ResearchUnlockCount = 0; // abilities can't be researched or duplicated
			All.Add(this);
		}

		public override void Unload() {
			All.Clear();
		}

		public override void SetDefaults() {
			Item.maxStack = 1;
			Item.value = 0;
			Item.rare = ItemRarityID.Cyan;
			Item.DamageType = DamageClass.Ranged;
			Item.noMelee = true;
		}

		public override bool CanUseItem(Player player) {
			return player.GetModPlayer<RobotJackPlayer>().Transformed;
		}

		public override void UpdateInventory(Player player) {
			if (!player.GetModPlayer<RobotJackPlayer>().Transformed) {
				Item.TurnToAir();
			}
		}

		// Dropped in the world: disappear.
		public override void PostUpdate() {
			Item.TurnToAir();
		}

		public override void ModifyWeaponDamage(Player player, ref StatModifier damage) {
			damage *= ProgressionMultiplier();
		}
	}
}
