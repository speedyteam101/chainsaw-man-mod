using Terraria;
using Terraria.ID;

namespace ChainsawManMod.Content.Items
{
	// Endgame upgrade of the Starter Cord.
	public class HeroOfHellsCord : StarterCordBase
	{
		public override int Tier => 3;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 20);
			Item.rare = ItemRarityID.Red;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<RevvedStarterCord>()
				.AddIngredient(ItemID.LunarBar, 10)
				.AddIngredient(ItemID.FragmentSolar, 15)
				.AddTile(TileID.LunarCraftingStation)
				.Register();
		}
	}
}
