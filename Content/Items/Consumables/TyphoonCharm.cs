using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons the Typhoon Devil. Hardmode only.
	public class TyphoonCharm : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<TyphoonDevil>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 2);
			Item.rare = ItemRarityID.Pink;
		}

		public override bool CanUseItem(Player player) {
			return Main.hardMode && base.CanUseItem(player);
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(20)
				.AddIngredient(ItemID.Feather, 10)
				.AddIngredient(ItemID.SoulofFlight, 5)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}
}
