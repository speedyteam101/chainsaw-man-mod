using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons the Zombie Devil.
	public class RottingOffering : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<ZombieDevil>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(silver: 20);
			Item.rare = ItemRarityID.Blue;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(8)
				.AddTile(TileID.DemonAltar)
				.Register();
		}
	}
}
