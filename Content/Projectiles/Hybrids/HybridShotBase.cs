using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Shared behaviour for the player's hybrid-form shots.
	public abstract class HybridShotBase : ModProjectile
	{
		protected abstract int DustType { get; }
		protected virtual int Size => 14;
		protected virtual int Pierce => 1;          // -1 = unlimited
		protected virtual int Lifetime => 120;
		protected virtual float Gravity => 0f;
		protected virtual float Drag => 1f;         // velocity multiplier per tick
		protected virtual int DebuffType => -1;
		protected virtual bool CollideTiles => true;
		protected virtual bool Invisible => false;  // only dust is drawn
		protected virtual int DustChance => 2;      // 1 in N ticks

		public override void SetDefaults() {
			Projectile.width = Size;
			Projectile.height = Size;
			Projectile.friendly = true;
			Projectile.hostile = false;
			Projectile.DamageType = DamageClass.Generic;
			Projectile.penetrate = Pierce;
			Projectile.timeLeft = Lifetime;
			Projectile.tileCollide = CollideTiles;
			Projectile.ignoreWater = true;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1; // hits each enemy once
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			Projectile.velocity.Y += Gravity;
			Projectile.velocity *= Drag;
			Projectile.rotation = Projectile.velocity.ToRotation();

			if (Main.rand.NextBool(DustChance)) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustType);
				dust.noGravity = true;
				dust.velocity *= 0.3f;
			}
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			if (DebuffType >= 0) {
				target.AddBuff(DebuffType, 240);
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			return !Invisible;
		}

		public override Color? GetAlpha(Color lightColor) {
			return Color.White * Projectile.Opacity;
		}
	}
}
