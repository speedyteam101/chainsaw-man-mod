using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Quanxi (Bow Hybrid): a fan of five arrows.
	public class ArrowBarrage : SpreadShotAbility
	{
		public override HybridType Hybrid => HybridType.Bow;
		protected override int Count => 5;
		protected override float SpreadDegrees => 5f;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 22;
			Item.useAnimation = 22;
			Item.autoReuse = true;
			Item.damage = 40;
			Item.UseSound = SoundID.Item5;
			Item.shoot = ModContent.ProjectileType<DevilArrow>();
			Item.shootSpeed = 16f;
		}
	}

	// One heavy arrow that pierces through up to 10 enemies and walls.
	public class PiercingShot : SpreadShotAbility
	{
		public override HybridType Hybrid => HybridType.Bow;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 50;
			Item.useAnimation = 50;
			Item.damage = 150;
			Item.knockBack = 6f;
			Item.UseSound = SoundID.Item5;
			Item.shoot = ModContent.ProjectileType<PiercingArrow>();
			Item.shootSpeed = 24f;
		}
	}
}
