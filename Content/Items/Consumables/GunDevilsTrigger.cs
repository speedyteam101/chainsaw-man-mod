using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons the Gun Devil. Only works after Plantera has been defeated.
	public class GunDevilsTrigger : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<GunDevil>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 5);
			Item.rare = ItemRarityID.Lime;
		}

		public override bool CanUseItem(Player player) {
			return NPC.downedPlantBoss && base.CanUseItem(player);
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<GunDevilFragment>(15)
				.AddIngredient<DevilFlesh>(10)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}
}
