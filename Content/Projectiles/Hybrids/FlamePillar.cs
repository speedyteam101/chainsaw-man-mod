using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Flamethrower form: Fire Wall. A lingering column of fire (drawn with dust).
	public class FlamePillar : ModProjectile
	{
		public override void SetDefaults() {
			Projectile.width = 34;
			Projectile.height = 96;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Generic;
			Projectile.penetrate = -1;
			Projectile.timeLeft = 120;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = 20;
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			Lighting.AddLight(Projectile.Center, 1f, 0.5f, 0.1f);
			for (int i = 0; i < 3; i++) {
				Dust dust = Dust.NewDustDirect(Projectile.position, Projectile.width, Projectile.height, DustID.Torch, 0f, -3f, 0, default, 1.8f);
				dust.noGravity = true;
			}
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.OnFire, 300);
		}

		public override bool PreDraw(ref Color lightColor) {
			return false;
		}
	}
}
