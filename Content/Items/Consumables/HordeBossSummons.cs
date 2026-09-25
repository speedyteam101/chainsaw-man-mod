using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.NPCs.Bosses;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summon items for the second wave of bosses. Each is locked until its point in progression.
	public abstract class HordeBossSummon : DevilSummonItemBase
	{
		protected abstract bool Unlocked { get; }

		public override bool CanUseItem(Player player) {
			return Unlocked && base.CanUseItem(player);
		}
	}

	public class LeechBait : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<LeechQueen>();
		protected override bool Unlocked => true;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Blue;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(12)
				.AddTile(TileID.Anvils)
				.Register();
		}
	}

	public class SilkCocoon : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<SpiderQueen>();
		protected override bool Unlocked => NPC.downedBoss2;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Green;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(15)
				.AddIngredient(ItemID.Silk, 10)
				.AddTile(TileID.Anvils)
				.Register();
		}
	}

	public class FrozenHeart : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<FrostDevil>();
		protected override bool Unlocked => NPC.downedBoss3;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Orange;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(20)
				.AddTile(TileID.Anvils)
				.Register();
		}
	}

	public class DesertSeal : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<SandColossus>();
		protected override bool Unlocked => Main.hardMode;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.LightRed;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(25)
				.AddIngredient(ItemID.SoulofNight, 5)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}

	public class KrakenInk : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<KrakenDevil>();
		protected override bool Unlocked => Main.hardMode;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.LightRed;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(25)
				.AddIngredient(ItemID.SoulofLight, 5)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}

	public class FutureClock : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<FutureDevil>();
		protected override bool Unlocked => NPC.downedMechBossAny;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Pink;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(30)
				.AddIngredient(ItemID.HallowedBar, 10)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}

	public class WarBanner : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<WarDevil>();
		protected override bool Unlocked => NPC.downedPlantBoss;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Lime;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(30)
				.AddIngredient<GunDevilFragment>(10)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}

	public class EmptyBowl : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<FamineDevil>();
		protected override bool Unlocked => NPC.downedGolemBoss;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Yellow;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(30)
				.AddIngredient(ItemID.ChlorophyteBar, 10)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}

	public class FallingStarShard : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<FallingDevil>();
		protected override bool Unlocked => NPC.downedMoonlord;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Red;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.LunarBar, 10)
				.AddIngredient<DevilFlesh>(30)
				.AddTile(TileID.LunarCraftingStation)
				.Register();
		}
	}

	public class DeathsContract : HordeBossSummon
	{
		protected override int BossType => ModContent.NPCType<DeathDevil>();
		protected override bool Unlocked => DownedDevilSystem.downedMakima;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Red;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.LunarBar, 20)
				.AddIngredient<DevilFlesh>(50)
				.AddTile(TileID.LunarCraftingStation)
				.Register();
		}
	}
}
