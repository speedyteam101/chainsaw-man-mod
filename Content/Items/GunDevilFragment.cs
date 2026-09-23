using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items
{
	// Crafting material dropped by Gun Devil Spawn and the Gun Devil.
	public class GunDevilFragment : ModItem
	{
		public override void SetStaticDefaults() {
			Item.ResearchUnlockCount = 25;
		}

		public override void SetDefaults() {
			Item.width = 22;
			Item.height = 22;
			Item.maxStack = Item.CommonMaxStack;
			Item.value = Item.sellPrice(silver: 50);
			Item.rare = ItemRarityID.Lime;
		}
	}
}
