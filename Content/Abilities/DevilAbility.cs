using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Items;
using System.Collections.Generic;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Base class for form ability items (Chainsaw Man and the hybrid forms).
	// ChainsawManPlayer puts these in the player's inventory while transformed and removes them afterwards.
	// They can't be kept: they vanish if the form ends, the Starter Cord tier is too low, or they're dropped in the world.
	public abstract class DevilAbility : ModItem
	{
		// Every ability, in load order. ChainsawManPlayer hands out the ones the current form allows.
		public static readonly List<DevilAbility> All = new();

		// Which hybrid form grants this ability. None = a Chainsaw Man ability.
		public virtual HybridType Hybrid => HybridType.None;

		// Chainsaw Man abilities only: lowest Starter Cord tier that grants this ability.
		public virtual int RequiredTier => 1;

		// Damaging abilities scale like the Chainsaw Arm: progression bonus, plus the form multiplier for Chainsaw Man.
		protected virtual bool ScalesDamage => true;

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
			Item.rare = ItemRarityID.Red;
		}

		public bool IsAllowed(Player player) {
			ChainsawManPlayer modPlayer = player.GetModPlayer<ChainsawManPlayer>();
			if (Hybrid == HybridType.None) {
				return modPlayer.ActiveFormTier >= RequiredTier;
			}
			return modPlayer.ActiveHybrid == Hybrid;
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
				if (Hybrid == HybridType.None) {
					damage *= ChainsawArm.FormMultiplier(player.GetModPlayer<ChainsawManPlayer>().ActiveFormTier);
				}
				// Hybrid forms get their damage boost from HybridFormBuff instead.
			}
		}
	}
}
