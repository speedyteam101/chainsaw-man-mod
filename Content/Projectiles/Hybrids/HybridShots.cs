using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Bow form: Arrow Barrage.
	public class DevilArrow : HybridShotBase
	{
		protected override int DustType => DustID.Silver;
		protected override int Size => 10;
		protected override int Pierce => 2;
		protected override float Gravity => 0.08f;
	}

	// Bow form: Piercing Shot. Goes through up to 10 enemies.
	public class PiercingArrow : HybridShotBase
	{
		protected override int DustType => DustID.WhiteTorch;
		protected override int Pierce => 10;
		protected override int Lifetime => 90;
		protected override bool CollideTiles => false;
		protected override int DustChance => 1;
	}

	// Flamethrower form: Flame Breath. Short-lived, slows down, sets enemies on fire.
	public class FlameBolt : HybridShotBase
	{
		protected override int DustType => DustID.Torch;
		protected override int Size => 18;
		protected override int Pierce => 3;
		protected override int Lifetime => 30;
		protected override float Drag => 0.96f;
		protected override int DebuffType => BuffID.OnFire;
		protected override bool Invisible => true;
		protected override int DustChance => 1;

		public override void AI() {
			base.AI();
			// Extra flame dust so the stream looks full.
			Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustID.Torch, Projectile.velocity.X * 0.3f, Projectile.velocity.Y * 0.3f, 0, default, 1.8f);
			dust.noGravity = true;
		}
	}

	// Katana form: Slash Wave. A crescent blade that flies through enemies.
	public class KatanaWave : HybridShotBase
	{
		protected override int DustType => DustID.Silver;
		protected override int Size => 40;
		protected override int Pierce => 6;
		protected override int Lifetime => 40;
		protected override bool CollideTiles => false;

		public override void AI() {
			base.AI();
			if (Projectile.timeLeft < 10) {
				Projectile.alpha += 25; // fade out
			}
		}
	}

	// Spear form: Spear Thrust and Spear Rain.
	public class DevilSpear : HybridShotBase
	{
		protected override int DustType => DustID.Silver;
		protected override int Size => 16;
		protected override int Pierce => 5;
		protected override int Lifetime => 50;
		protected override bool CollideTiles => false;
	}

	// Bomb form: Explosive Punch. Explodes on hit or when it runs out.
	public class ExplosiveFist : HybridShotBase
	{
		protected override int DustType => DustID.Torch;
		protected override int Size => 20;
		protected override int Lifetime => 25;

		public override void OnKill(int timeLeft) {
			if (Projectile.owner == Main.myPlayer) {
				Projectile.NewProjectile(Projectile.GetSource_FromThis(), Projectile.Center, Microsoft.Xna.Framework.Vector2.Zero,
					ModContent.ProjectileType<BombExplosion>(), Projectile.damage, Projectile.knockBack, Projectile.owner);
			}
		}
	}
}
