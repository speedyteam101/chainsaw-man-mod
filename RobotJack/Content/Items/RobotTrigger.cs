using RobotJack.Content.Buffs;
using Terraria;
using Terraria.Audio;
using Terraria.ID;
using Terraria.Localization;
using Terraria.ModLoader;

namespace RobotJack.Content.Items
{
	// Found, not crafted: underground Gold Chests (see RobotJackWorldGen) and a rare drop from
	// enemies killed underground (see RobotTriggerDrop). Use it to become Robot Jack, use it again to turn back.
	public class RobotTrigger : ModItem
	{
		public override LocalizedText Tooltip => base.Tooltip.WithFormatArgs(
			RobotForm.DamageBonus, RobotForm.DefenseBonus, RobotForm.DamageReduction, RobotForm.MoveSpeedBonus);

		public override void SetDefaults() {
			Item.width = 28;
			Item.height = 32;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.value = Item.sellPrice(gold: 2);
			Item.rare = ItemRarityID.LightRed;
		}

		public override bool? UseItem(Player player) {
			int formBuff = ModContent.BuffType<RobotForm>();
			bool transforming = !player.HasBuff(formBuff);

			if (player.whoAmI == Main.myPlayer) {
				if (transforming) {
					player.AddBuff(formBuff, 2);
				}
				else {
					player.ClearBuff(formBuff);
				}
			}

			SoundEngine.PlaySound(transforming ? SoundID.Item113 : SoundID.Item94, player.Center);
			for (int i = 0; i < 30; i++) {
				Dust dust = Dust.NewDustDirect(player.position, player.width, player.height, DustID.Electric,
					Main.rand.NextFloat(-3f, 3f), Main.rand.NextFloat(-3f, 3f));
				dust.noGravity = true;
			}

			return true;
		}
	}
}
