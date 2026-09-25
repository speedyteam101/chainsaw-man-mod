using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons the Darkness Devil. Only works after the Moon Lord has been defeated.
	public class DarknessShard : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<DarknessDevil>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 10);
			Item.rare = ItemRarityID.Red;
		}

		public override bool CanUseItem(Player player) {
			return NPC.downedMoonlord && base.CanUseItem(player);
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.LunarBar, 10)
				.AddIngredient<DevilFlesh>(30)
				.AddIngredient(ItemID.SoulofNight, 10)
				.AddTile(TileID.LunarCraftingStation)
				.Register();
		}
	}
}
