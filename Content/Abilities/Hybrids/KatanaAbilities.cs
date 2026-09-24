using ChainsawManMod.Content.Hybrids;
using ChainsawManMod.Content.Projectiles.Hybrids;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities.Hybrids
{
	// Katana Man: fast swings with the arm blades.
	public class KatanaSlash : SwingAbility
	{
		public override HybridType Hybrid => HybridType.Katana;
		protected override int DustType => DustID.Silver;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 14;
			Item.useAnimation = 14;
			Item.scale = 1.6f;
			Item.damage = 70;
			Item.crit = 15;
		}
	}

	// A lightning-fast draw: dash through enemies, cutting everything on the way.
	public class QuickDraw : DashAbility
	{
		public override HybridType Hybrid => HybridType.Katana;
		protected override int DustType => DustID.Silver;
		protected override float DashSpeed => 24f;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 45;
			Item.useAnimation = 45;
			Item.damage = 110;
			Item.UseSound = SoundID.Item1;
		}
	}

	// Throw a crescent-shaped cut that flies through enemies.
	public class SlashWave : SpreadShotAbility
	{
		public override HybridType Hybrid => HybridType.Katana;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.useTime = 25;
			Item.useAnimation = 25;
			Item.autoReuse = true;
			Item.damage = 65;
			Item.UseSound = SoundID.Item1;
			Item.shoot = ModContent.ProjectileType<KatanaWave>();
			Item.shootSpeed = 16f;
		}
	}
}
