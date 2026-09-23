using ChainsawManMod.Content.Buffs;
using Terraria;
using Terraria.ID;
using Terraria.Localization;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Tier 1: drink blood to heal a big chunk of health. Has a cooldown.
	public class BloodDrink : DevilAbility
	{
		public static readonly int HealPercent = 30;
		public static readonly int CooldownSeconds = 20;

		public override int RequiredTier => 1;
		protected override bool ScalesDamage => false;

		public override LocalizedText Tooltip => base.Tooltip.WithFormatArgs(HealPercent, CooldownSeconds);

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 20;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.DrinkLiquid;
			Item.useTime = 17;
			Item.useAnimation = 17;
			Item.UseSound = SoundID.Item3;
		}

		public override bool CanUseItem(Player player) {
			return base.CanUseItem(player) && !player.HasBuff(ModContent.BuffType<BloodDrinkCooldown>());
		}

		public override bool? UseItem(Player player) {
			if (player.whoAmI == Main.myPlayer) {
				int heal = System.Math.Min(player.statLifeMax2 * HealPercent / 100, player.statLifeMax2 - player.statLife);
				if (heal > 0) {
					player.statLife += heal;
					player.HealEffect(heal);
				}
				player.AddBuff(ModContent.BuffType<BloodDrinkCooldown>(), CooldownSeconds * 60);
			}
			return true;
		}
	}
}
