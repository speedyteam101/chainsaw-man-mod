using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons the Eternity Devil. Hardmode only.
	public class CursedHotelKey : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<EternityDevil>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 22;
			Item.value = Item.sellPrice(gold: 2);
			Item.rare = ItemRarityID.Pink;
		}

		public override bool CanUseItem(Player player) {
			return Main.hardMode && base.CanUseItem(player);
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(20)
				.AddIngredient(ItemID.SoulofNight, 8)
				.AddIngredient(ItemID.GoldenKey)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}
}
