using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Buffs;
using Terraria;
using Terraria.ID;
using Terraria.Localization;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items
{
	// Pull the cord to turn into the Chainsaw Devil. Requires Pochita's Heart to be equipped.
	public class StarterCord : ModItem
	{
		public static readonly int FormSeconds = 30;
		public static readonly int CooldownSeconds = 90;

		public override LocalizedText Tooltip => base.Tooltip.WithFormatArgs(FormSeconds, CooldownSeconds);

		public override void SetDefaults() {
			Item.width = 22;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.UseSound = SoundID.Item22;
			Item.value = Item.sellPrice(silver: 50);
			Item.rare = ItemRarityID.Orange;
		}

		public override bool CanUseItem(Player player) {
			return player.GetModPlayer<ChainsawManPlayer>().hasPochitaHeart
				&& !player.HasBuff(ModContent.BuffType<StarterCordCooldown>());
		}

		public override bool? UseItem(Player player) {
			if (player.whoAmI == Main.myPlayer) {
				player.AddBuff(ModContent.BuffType<ChainsawDevilForm>(), FormSeconds * 60);
				player.AddBuff(ModContent.BuffType<StarterCordCooldown>(), CooldownSeconds * 60);
			}

			for (int i = 0; i < 20; i++) {
				Dust.NewDust(player.position, player.width, player.height, DustID.Blood, Main.rand.NextFloat(-2f, 2f), Main.rand.NextFloat(-4f, 0f));
			}

			return true;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.Rope, 10)
				.AddRecipeGroup(RecipeGroupID.IronBar, 3)
				.AddTile(TileID.Anvils)
				.Register();
		}
	}
}
