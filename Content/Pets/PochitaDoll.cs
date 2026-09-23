using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Pets
{
	public class PochitaDoll : ModItem
	{
		public override void SetDefaults() {
			Item.CloneDefaults(ItemID.ZephyrFish);

			Item.shoot = ModContent.ProjectileType<PochitaPetProjectile>();
			Item.buffType = ModContent.BuffType<PochitaPetBuff>();
		}

		public override bool? UseItem(Player player) {
			if (player.whoAmI == Main.myPlayer) {
				player.AddBuff(Item.buffType, 3600);
			}
			return true;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.Silk, 10)
				.AddIngredient(ItemID.Chain, 2)
				.AddTile(TileID.Loom)
				.Register();
		}
	}
}
