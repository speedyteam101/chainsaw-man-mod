using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Projectiles.Hybrids
{
	// Friendly explosion (Bomb form). A short-lived damaging area; only dust and sound are shown. Never hurts the player.
	public class BombExplosion : ModProjectile
	{
		public override void SetDefaults() {
			Projectile.width = 180;
			Projectile.height = 180;
			Projectile.friendly = true;
			Projectile.hostile = false;
			Projectile.DamageType = DamageClass.Generic;
			Projectile.penetrate = -1;
			Projectile.timeLeft = 10;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1;
			Projectile.aiStyle = -1;
		}

		public override void AI() {
			if (Projectile.ai[0] == 0f) {
				Projectile.ai[0] = 1f;
				SoundEngine.PlaySound(SoundID.Item14, Projectile.Center);
				for (int i = 0; i < 50; i++) {
					Vector2 speed = Main.rand.NextVector2Circular(9f, 9f);
					Dust fire = Dust.NewDustPerfect(Projectile.Center, DustID.Torch, speed, 0, default, 2.2f);
					fire.noGravity = true;
				}
				for (int i = 0; i < 20; i++) {
					Dust.NewDustPerfect(Projectile.Center, DustID.Smoke, Main.rand.NextVector2Circular(5f, 5f), 100, default, 1.8f);
				}
			}
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.OnFire, 240);
		}

		public override bool PreDraw(ref Color lightColor) {
			return false;
		}
	}
}
