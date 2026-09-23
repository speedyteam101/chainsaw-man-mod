using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Items;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Base class for Chainsaw Devil ability items.
	// ChainsawManPlayer puts these in the player's inventory while transformed and removes them afterwards.
	// They can't be kept: they vanish if the form ends, the Starter Cord tier is too low, or they're dropped in the world.
	public abstract class DevilAbility : ModItem
	{
		// Lowest Starter Cord tier that grants this ability.
		public abstract int RequiredTier { get; }

		// Damaging abilities scale like the Chainsaw Arm: progression bonus plus the form multiplier.
		protected virtual bool ScalesDamage => true;

		public override void SetStaticDefaults() {
			Item.ResearchUnlockCount = 0; // abilities can't be researched or duplicated
		}

		public override void SetDefaults() {
			Item.maxStack = 1;
			Item.value = 0;
			Item.rare = ItemRarityID.Red;
		}

		public bool IsAllowed(Player player) {
			return player.GetModPlayer<ChainsawManPlayer>().ActiveFormTier >= RequiredTier;
		}

		public override bool CanUseItem(Player player) {
			return IsAllowed(player);
		}

		public override void UpdateInventory(Player player) {
			if (!IsAllowed(player)) {
				Item.TurnToAir();
			}
		}

		// Dropped in the world: disappear.
		public override void PostUpdate() {
			Item.TurnToAir();
		}

		public override void ModifyWeaponDamage(Player player, ref StatModifier damage) {
			if (ScalesDamage) {
				damage.Base += ChainsawArm.ProgressionBonus();
				damage *= ChainsawArm.FormMultiplier(player.GetModPlayer<ChainsawManPlayer>().ActiveFormTier);
			}
		}
	}
}
