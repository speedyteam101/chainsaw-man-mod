using Terraria;
using Terraria.ID;

namespace ChainsawManMod.Content.Items
{
	// Hardmode upgrade of the Starter Cord.
	public class RevvedStarterCord : StarterCordBase
	{
		public override int Tier => 2;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 5);
			Item.rare = ItemRarityID.Pink;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<StarterCord>()
				.AddIngredient(ItemID.HallowedBar, 10)
				.AddIngredient(ItemID.SoulofMight, 5)
				.AddIngredient(ItemID.SoulofFright, 5)
				.AddIngredient(ItemID.SoulofSight, 5)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}
}
