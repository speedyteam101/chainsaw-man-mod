using Terraria;
using Terraria.ID;

namespace ChainsawManMod.Content.Items
{
	public class StarterCord : StarterCordBase
	{
		public override int Tier => 1;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(silver: 50);
			Item.rare = ItemRarityID.Orange;
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
