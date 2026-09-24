using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Buffs;
using Terraria;
using Terraria.ID;
using Terraria.Localization;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items
{
	// Shared behaviour for every tier of the Starter Cord.
	// Using a cord toggles the Chainsaw Devil form on and off. The form lasts until you turn it off (or die), with no cooldown.
	// Higher tiers are crafted from the previous tier and give a stronger form.
	public abstract class StarterCordBase : ModItem
	{
		// 1 = Starter Cord, 2 = Revved Starter Cord, 3 = Hero of Hell's Cord
		public abstract int Tier { get; }

		public override LocalizedText Tooltip => base.Tooltip.WithFormatArgs(
			ChainsawDevilForm.MeleeDamageBonus(Tier),
			ChainsawDevilForm.MeleeSpeedBonus(Tier),
			ChainsawDevilForm.DefenseBonus(Tier),
			ChainsawDevilForm.MoveSpeedBonus(Tier),
			ChainsawDevilForm.CritBonus(Tier),
			ChainsawDevilForm.DamageReduction(Tier),
			ChainsawDevilForm.LifeRegen(Tier));

		public override void SetDefaults() {
			Item.width = 22;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.UseSound = SoundID.Item22;
		}

		public override bool CanUseItem(Player player) {
			return player.GetModPlayer<ChainsawManPlayer>().hasPochitaHeart;
		}

		public override bool? UseItem(Player player) {
			if (player.whoAmI == Main.myPlayer) {
				ChainsawManPlayer modPlayer = player.GetModPlayer<ChainsawManPlayer>();
				int formBuff = ModContent.BuffType<ChainsawDevilForm>();

				if (player.HasBuff(formBuff) && modPlayer.selectedFormTier == Tier) {
					// Same cord pulled again: turn back into a human.
					player.ClearBuff(formBuff);
				}
				else {
					// Transform, or switch to this cord's tier if already transformed.
					modPlayer.selectedFormTier = Tier;
					player.AddBuff(formBuff, 2);
				}
			}

			for (int i = 0; i < 20; i++) {
				Dust.NewDust(player.position, player.width, player.height, DustID.Blood, Main.rand.NextFloat(-2f, 2f), Main.rand.NextFloat(-4f, 0f));
			}

			return true;
		}
	}
}
